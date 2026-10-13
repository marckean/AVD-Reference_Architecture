<#
.SYNOPSIS
Inventories App-V packages without the App-V client.

.DESCRIPTION
Reads one or more .appv files from a folder or file share, opens each package as a zip archive, reads AppxManifest.xml with namespace-agnostic XPath, and returns one object per package.

The script reports identity metadata, contained applications, manifest integration points, package size, whether standard App-V dynamic configuration files sit beside the package, and whether those configuration files contain script elements.

It also rates how much work each package is likely to need if you convert it to MSIX later. ConversionEffort is High when the package has dynamic configuration scripts, services or shell extensions, Medium when it has COM, fonts or environment variables, and Low otherwise. ConversionNotes says why, and what to check. The rating is a triage aid that helps you plan, not a compatibility test.

Microsoft Learn confirms that App Attach can use App-V packages, and that App-V Dynamic Configuration files named <package>_UserConfig.xml and <package>_DeploymentConfig.xml in the same folder are automatically detected for App-V packages delivered through App Attach.

.PARAMETER Path
One or more .appv files or folders that contain .appv files.

.PARAMETER Recurse
Searches folders recursively for .appv files.

.PARAMETER CsvPath
Optional path for a CSV export. Array properties are flattened to semicolon-separated strings.

.PARAMETER JsonPath
Optional path for a JSON export. The full object shape is preserved.

.EXAMPLE
.\Get-AppVPackageInventory.ps1 -Path \\contoso.file.core.windows.net\packages -Recurse

Inventories every .appv package under a file share.

.EXAMPLE
.\Get-AppVPackageInventory.ps1 -Path C:\Packages\App1.appv -CsvPath C:\Temp\appv-inventory.csv -JsonPath C:\Temp\appv-inventory.json

Inventories one package and writes CSV and JSON exports.

.EXAMPLE
.\Get-AppVPackageInventory.ps1 -Path \\contoso.file.core.windows.net\packages -Recurse | Where-Object ConversionEffort -eq 'Low' | Select-Object PackageName, ConversionEffort, ConversionNotes

Lists the packages likely to convert to MSIX with the least effort, which make a good first conversion wave.

.NOTES
Sources:
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview
https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy
https://learn.microsoft.com/windows/msix/packaging-tool/create-app-package
https://learn.microsoft.com/windows/msix/packaging-tool/tool-known-issues
https://learn.microsoft.com/windows/msix/packaging-tool/convert-an-installer-with-services
https://learn.microsoft.com/windows/msix/psf/run-scripts-with-package-support-framework
https://learn.microsoft.com/windows/msix/psf/psf-integration-with-mpt
https://learn.microsoft.com/windows/apps/desktop/modernize/desktop-to-uwp-extensions

.LINK
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview

.LINK
https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter()]
    [switch] $Recurse,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CsvPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $JsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LocalNameNode {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode] $Node,

        [Parameter(Mandatory)]
        [string] $LocalName
    )

    $expression = "//*[local-name()='$LocalName']"
    return $Node.SelectNodes($expression)
}

function Get-NodeText {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode] $Node
    )

    if ($null -eq $Node) {
        return $null
    }

    return $Node.InnerText
}

function Get-AttributeValue {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode] $Node,

        [Parameter(Mandatory)]
        [string[]] $Names
    )

    foreach ($attribute in $Node.Attributes) {
        foreach ($name in $Names) {
            if ($attribute.LocalName -ieq $name) {
                return $attribute.Value
            }
        }
    }

    return $null
}

function ConvertTo-NameValueList {
    param(
        [Parameter(Mandatory)]
        [object[]] $Nodes
    )

    $items = foreach ($node in $Nodes) {
        $name = Get-AttributeValue -Node $node -Names @('Name', 'Id', 'Category', 'Type')
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = $node.LocalName
        }

        $name
    }

    return @($items | Sort-Object -Unique)
}

function Test-XmlContainsScript {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return $false
    }

    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.PreserveWhitespace = $false
        $document.Load($FilePath)
        $scriptNodes = $document.SelectNodes("//*[contains(translate(local-name(), 'SCRIPT', 'script'), 'script')]")
        if ($null -ne $scriptNodes -and $scriptNodes.Count -gt 0) {
            return $true
        }
    }
    catch {
        Write-Verbose "Could not parse dynamic configuration file '$FilePath': $($_.Exception.Message)"
    }

    return $false
}

function Get-IntegrationSummary {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument] $Manifest
    )

    $knownPatterns = [ordered]@{
        Shortcuts = 'Shortcut'
        FileTypeAssociations = 'FileTypeAssociation'
        UrlProtocols = 'URLProtocol'
        Com = 'COM'
        Services = 'Service'
        ShellExtensions = 'ShellExtension'
        Fonts = 'Font'
        EnvironmentVariables = 'EnvironmentVariable'
        Dependencies = 'Dependency'
        Extensions = 'Extension'
        Capabilities = 'Capability'
    }

    $result = [ordered]@{}
    foreach ($item in $knownPatterns.GetEnumerator()) {
        $nodes = Get-LocalNameNode -Node $Manifest -LocalName $item.Value
        $result[$item.Key] = [pscustomobject]@{
            Present = ($null -ne $nodes -and $nodes.Count -gt 0)
            Count = if ($null -eq $nodes) { 0 } else { $nodes.Count }
            Values = if ($null -eq $nodes) { @() } else { ConvertTo-NameValueList -Nodes @($nodes) }
        }
    }

    $extensionCategories = @()
    $extensionNodes = Get-LocalNameNode -Node $Manifest -LocalName 'Extension'
    foreach ($extensionNode in $extensionNodes) {
        $category = Get-AttributeValue -Node $extensionNode -Names @('Category')
        if (-not [string]::IsNullOrWhiteSpace($category)) {
            $extensionCategories += $category
        }
    }

    $allElementNames = @($Manifest.SelectNodes('//*') | ForEach-Object { $_.LocalName } | Sort-Object -Unique)
    $knownElementNames = @('Application', 'Applications', 'Identity') + @($knownPatterns.Values)
    $otherIntegrationElements = @($allElementNames | Where-Object { $_ -notin $knownElementNames })

    return [pscustomobject]@{
        Known = [pscustomobject]$result
        ExtensionCategories = @($extensionCategories | Sort-Object -Unique)
        OtherManifestElements = $otherIntegrationElements
    }
}

function Get-ConversionAssessment {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Integration,

        [Parameter()]
        [bool] $DynamicConfigContainsScripts,

        [Parameter()]
        [string] $SequencerVersion
    )

    # Each rule is grounded in the Microsoft Learn sources listed in the help. High means
    # the conversion usually needs a person to rebuild or redesign something, Medium means
    # it usually needs a manifest change or a Package Support Framework fixup, and Check
    # means it usually converts but must be tested.
    $known = $Integration.Known
    $findings = [System.Collections.Generic.List[pscustomobject]]::new()

    if ($DynamicConfigContainsScripts) {
        $findings.Add([pscustomobject]@{ Level = 'High'; Note = 'Dynamic configuration scripts: MSIX has no dynamic configuration file, so rebuild them as Package Support Framework start or end scripts, which need the PowerShell execution policy set to RemoteSigned, or remove the need for them.' })
    }
    if ($known.Services.Present) {
        $findings.Add([pscustomobject]@{ Level = 'High'; Note = 'Services: check the services report in the MSIX Packaging Tool, which lists included and excluded services. MSIX packages with services need Windows 10 version 2004 or later.' })
    }
    if ($known.ShellExtensions.Present) {
        $findings.Add([pscustomobject]@{ Level = 'High'; Note = 'Shell extensions: context menus are not added automatically during conversion, so add them to the manifest by hand and test them. Windows 11 supports MSIX shell extensions in the classic context menu.' })
    }
    if (-not [string]::IsNullOrWhiteSpace($SequencerVersion)) {
        $parsedVersion = $null
        if ([version]::TryParse($SequencerVersion, [ref] $parsedVersion) -and $parsedVersion -lt [version]'5.1') {
            $findings.Add([pscustomobject]@{ Level = 'High'; Note = "Sequencer version $($SequencerVersion): the MSIX Packaging Tool supports App-V 5.1 packages, so if conversion fails, convert from the source installer instead." })
        }
    }
    if ($known.Com.Present) {
        $findings.Add([pscustomobject]@{ Level = 'Medium'; Note = 'COM: the MSIX manifest declares COM servers as extensions. Check the converted manifest and test whatever uses the COM components.' })
    }
    if ($known.Fonts.Present) {
        $findings.Add([pscustomobject]@{ Level = 'Medium'; Note = 'Fonts: MSIX shares fonts through a shared fonts extension in the manifest. Check the fonts are available to users after conversion.' })
    }
    if ($known.EnvironmentVariables.Present) {
        $findings.Add([pscustomobject]@{ Level = 'Medium'; Note = 'Environment variables: if the application needs them, add the Package Support Framework environment variable fixup in the Package Editor.' })
    }
    if ($known.FileTypeAssociations.Present) {
        $findings.Add([pscustomobject]@{ Level = 'Check'; Note = 'File type associations: results vary from package to package, so check each one opens the application after conversion.' })
    }
    if ($known.UrlProtocols.Present) {
        $findings.Add([pscustomobject]@{ Level = 'Check'; Note = 'URL protocols: MSIX declares them as a protocol extension in the manifest. Check each one still opens the application.' })
    }

    $levels = @($findings | ForEach-Object { $_.Level })
    $effort = if ($levels -contains 'High') {
        'High'
    }
    elseif ($levels -contains 'Medium') {
        'Medium'
    }
    else {
        'Low'
    }

    return [pscustomobject]@{
        Effort = $effort
        Notes = @($findings | ForEach-Object { $_.Note })
    }
}

function Get-AppVInventoryItem {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo] $Package
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $deploymentConfigPath = [System.IO.Path]::Combine($Package.DirectoryName, "$($Package.BaseName)_DeploymentConfig.xml")
    $userConfigPath = [System.IO.Path]::Combine($Package.DirectoryName, "$($Package.BaseName)_UserConfig.xml")

    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($Package.FullName)
        $manifestEntry = $archive.Entries | Where-Object { $_.FullName -ieq 'AppxManifest.xml' -or $_.FullName -ilike '*/AppxManifest.xml' } | Select-Object -First 1
        if ($null -eq $manifestEntry) {
            throw "AppxManifest.xml was not found in '$($Package.FullName)'."
        }

        $stream = $manifestEntry.Open()
        try {
            $document = [System.Xml.XmlDocument]::new()
            $document.PreserveWhitespace = $false
            $document.Load($stream)
        }
        finally {
            $stream.Dispose()
        }

        $identityNode = Get-LocalNameNode -Node $document -LocalName 'Identity' | Select-Object -First 1
        if ($null -eq $identityNode) {
            throw "Identity was not found in '$($Package.FullName)'."
        }

        $applications = foreach ($applicationNode in (Get-LocalNameNode -Node $document -LocalName 'Application')) {
            $visualElements = $applicationNode.SelectSingleNode("*[local-name()='VisualElements']")
            [pscustomobject]@{
                Id = Get-AttributeValue -Node $applicationNode -Names @('Id')
                Executable = Get-AttributeValue -Node $applicationNode -Names @('Executable')
                EntryPoint = Get-AttributeValue -Node $applicationNode -Names @('EntryPoint')
                DisplayName = if ($null -eq $visualElements) { $null } else { Get-AttributeValue -Node $visualElements -Names @('DisplayName') }
                Description = if ($null -eq $visualElements) { $null } else { Get-AttributeValue -Node $visualElements -Names @('Description') }
            }
        }

        $integration = Get-IntegrationSummary -Manifest $document
        $sequencerVersionNode = Get-LocalNameNode -Node $document -LocalName 'SequencerVersion' | Select-Object -First 1
        $sequencerVersion = if ($null -eq $sequencerVersionNode) { $null } else { (Get-NodeText -Node $sequencerVersionNode).Trim() }
        $deploymentConfigContainsScripts = Test-XmlContainsScript -FilePath $deploymentConfigPath
        $userConfigContainsScripts = Test-XmlContainsScript -FilePath $userConfigPath
        $assessment = Get-ConversionAssessment -Integration $integration -DynamicConfigContainsScripts ($deploymentConfigContainsScripts -or $userConfigContainsScripts) -SequencerVersion $sequencerVersion
        $readinessNotes = @(
            'App Attach supports App-V packages, and the App-V support policy says App-V app attach lets you use App-V packages with Azure Virtual Desktop without running your own App-V server.'
            'The App-V client and sequencer follow the lifecycle of their Windows version and are not deprecated. App-V server is in fixed extended support through 9 October 2029, and the support policy recommends migrating away from App-V, with MSIX as the modern package format.'
            'This inventory does not certify compatibility. Use manifest features to triage, and test each package in a representative host pool. Test converted packages on a clean machine that never had the original installer.'
        )

        return [pscustomobject]@{
            PackagePath = $Package.FullName
            PackageName = Get-AttributeValue -Node $identityNode -Names @('Name')
            Version = Get-AttributeValue -Node $identityNode -Names @('Version')
            Publisher = Get-AttributeValue -Node $identityNode -Names @('Publisher')
            ProcessorArchitecture = Get-AttributeValue -Node $identityNode -Names @('ProcessorArchitecture')
            PackageId = Get-AttributeValue -Node $identityNode -Names @('PackageId', 'PackageID')
            VersionId = Get-AttributeValue -Node $identityNode -Names @('VersionId', 'VersionID')
            FileSizeBytes = $Package.Length
            Applications = @($applications)
            ApplicationCount = @($applications).Count
            IntegrationPoints = $integration
            DeploymentConfigPath = if (Test-Path -LiteralPath $deploymentConfigPath -PathType Leaf) { $deploymentConfigPath } else { $null }
            HasDeploymentConfig = Test-Path -LiteralPath $deploymentConfigPath -PathType Leaf
            DeploymentConfigContainsScripts = $deploymentConfigContainsScripts
            UserConfigPath = if (Test-Path -LiteralPath $userConfigPath -PathType Leaf) { $userConfigPath } else { $null }
            HasUserConfig = Test-Path -LiteralPath $userConfigPath -PathType Leaf
            UserConfigContainsScripts = $userConfigContainsScripts
            SequencerVersion = $sequencerVersion
            ConversionEffort = $assessment.Effort
            ConversionNotes = $assessment.Notes
            ReadinessHint = ($readinessNotes -join ' ')
            LearnReferences = @(
                'https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview'
                'https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy'
                'https://learn.microsoft.com/windows/msix/packaging-tool/tool-known-issues'
            )
        }
    }
    catch {
        Write-Error -ErrorRecord $_
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }
}

function ConvertTo-CsvInventoryRow {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Item
    )

    $known = $Item.IntegrationPoints.Known
    [pscustomobject]@{
        PackagePath = $Item.PackagePath
        PackageName = $Item.PackageName
        Version = $Item.Version
        Publisher = $Item.Publisher
        ProcessorArchitecture = $Item.ProcessorArchitecture
        PackageId = $Item.PackageId
        VersionId = $Item.VersionId
        FileSizeBytes = $Item.FileSizeBytes
        Applications = (@($Item.Applications | ForEach-Object { "$($_.Id)|$($_.Executable)|$($_.DisplayName)" }) -join '; ')
        Shortcuts = $known.Shortcuts.Count
        FileTypeAssociations = $known.FileTypeAssociations.Count
        UrlProtocols = $known.UrlProtocols.Count
        Com = $known.Com.Count
        Services = $known.Services.Count
        ShellExtensions = $known.ShellExtensions.Count
        Fonts = $known.Fonts.Count
        EnvironmentVariables = $known.EnvironmentVariables.Count
        ExtensionCategories = (@($Item.IntegrationPoints.ExtensionCategories) -join '; ')
        OtherManifestElements = (@($Item.IntegrationPoints.OtherManifestElements) -join '; ')
        HasDeploymentConfig = $Item.HasDeploymentConfig
        DeploymentConfigContainsScripts = $Item.DeploymentConfigContainsScripts
        HasUserConfig = $Item.HasUserConfig
        UserConfigContainsScripts = $Item.UserConfigContainsScripts
        SequencerVersion = $Item.SequencerVersion
        ConversionEffort = $Item.ConversionEffort
        ConversionNotes = (@($Item.ConversionNotes) -join ' | ')
        ReadinessHint = $Item.ReadinessHint
    }
}

$packages = foreach ($itemPath in $Path) {
    $resolvedItems = Resolve-Path -LiteralPath $itemPath
    foreach ($resolvedItem in $resolvedItems) {
        $fileSystemItem = Get-Item -LiteralPath $resolvedItem.ProviderPath
        if ($fileSystemItem.PSIsContainer) {
            Get-ChildItem -LiteralPath $fileSystemItem.FullName -Filter '*.appv' -File -Recurse:$Recurse
        }
        elseif ($fileSystemItem.Extension -ieq '.appv') {
            $fileSystemItem
        }
        else {
            Write-Verbose "Skipping non-App-V file '$($fileSystemItem.FullName)'."
        }
    }
}

$inventory = @($packages | Sort-Object FullName -Unique | ForEach-Object { Get-AppVInventoryItem -Package $_ })

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $inventory | ForEach-Object { ConvertTo-CsvInventoryRow -Item $_ } | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $inventory | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonPath -Encoding utf8
}

$inventory
