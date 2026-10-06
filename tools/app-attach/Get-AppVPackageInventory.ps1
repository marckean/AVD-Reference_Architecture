<#
.SYNOPSIS
Inventories App-V packages without the App-V client.

.DESCRIPTION
Reads one or more .appv files from a folder or file share, opens each package as a zip archive, reads AppxManifest.xml with namespace-agnostic XPath, and returns one object per package.

The script reports identity metadata, contained applications, manifest integration points, package size, whether standard App-V dynamic configuration files sit beside the package, and whether those configuration files contain script elements.

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

.NOTES
Sources:
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview
https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy

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
        $readinessNotes = @(
            'App Attach supports App-V packages, and the App-V support policy says App-V app attach lets you use App-V packages with Azure Virtual Desktop without running your own App-V server.'
            'The App-V client and sequencer are in fixed extended support; the App-V server components are deprecated and support ends in April 2026.'
            'This inventory does not certify compatibility. Use manifest features to triage and test first in a representative host pool.'
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
            DeploymentConfigContainsScripts = Test-XmlContainsScript -FilePath $deploymentConfigPath
            UserConfigPath = if (Test-Path -LiteralPath $userConfigPath -PathType Leaf) { $userConfigPath } else { $null }
            HasUserConfig = Test-Path -LiteralPath $userConfigPath -PathType Leaf
            UserConfigContainsScripts = Test-XmlContainsScript -FilePath $userConfigPath
            ReadinessHint = ($readinessNotes -join ' ')
            LearnReferences = @(
                'https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview'
                'https://learn.microsoft.com/microsoft-desktop-optimization-pack/app-v/appv-support-policy'
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
