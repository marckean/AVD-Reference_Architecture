<#
.SYNOPSIS
Creates MSIX Packaging Tool conversion templates from App-V inventory or installer CSV input.

.DESCRIPTION
Generates command-line conversion templates for the MSIX Packaging Tool from the output of Get-AppVPackageInventory.ps1 or from a CSV of source installers.

Microsoft Learn documents command-line conversions with the MSIX Packaging Tool and states that a template file is required for command-line conversion. Learn also documents App-V as an input to the MSIX Packaging Tool, with App-V 5.1 support.

The generated templates intentionally use "Do not sign package" semantics by omitting signing information. People must own certificate selection, signing, testing and approval before production use.

.PARAMETER InventoryJsonPath
Path to JSON output from Get-AppVPackageInventory.ps1.

.PARAMETER InstallerCsvPath
Path to a CSV file containing source installers. Supported columns are ApplicationName, InstallerPath, InstallerArguments, InstallLocation, PackageName, PackageDisplayName, PublisherName, PublisherDisplayName, Version, PackageOutputPath and TemplateOutputPath.

.PARAMETER OutputDirectory
Folder that receives conversion template XML files.

.PARAMETER PackageOutputDirectory
Folder to place the resulting MSIX packages when the templates are used.

.PARAMETER PublisherName
Publisher name for MSIX package identity, for example CN=Contoso.

.PARAMETER PublisherDisplayName
Publisher display name for generated templates.

.PARAMETER Version
Default package version to use when the inventory item does not include a version.

.PARAMETER Force
Allows overwriting existing template files.

.EXAMPLE
.\New-MsixConversionTemplate.ps1 -InventoryJsonPath .\appv-inventory.json -OutputDirectory .\templates -PackageOutputDirectory C:\MsixOut -PublisherName "CN=Contoso" -PublisherDisplayName "Contoso"

Creates one conversion template per inventory item.

.EXAMPLE
.\Get-AppVPackageInventory.ps1 -Path C:\AppV -Recurse -JsonPath C:\Temp\inventory.json
.\New-MsixConversionTemplate.ps1 -InventoryJsonPath C:\Temp\inventory.json -OutputDirectory C:\Temp\templates -PackageOutputDirectory C:\Temp\msix -PublisherName "CN=Contoso" -PublisherDisplayName "Contoso" -Force

Inventories packages, then creates template files.

.EXAMPLE
.\New-MsixConversionTemplate.ps1 -InstallerCsvPath .\source-installers.csv -OutputDirectory C:\Temp\templates -PackageOutputDirectory C:\Temp\msix -PublisherName "CN=Contoso" -PublisherDisplayName "Contoso"

Creates conversion templates from an installer CSV after application triage.

.NOTES
Sources:
https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file
https://learn.microsoft.com/windows/msix/packaging-tool/create-app-package

.LINK
https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(ParameterSetName = 'Inventory', Mandatory)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "Inventory JSON file '$_' was not found."
        }
        return $true
    })]
    [string] $InventoryJsonPath,

    [Parameter(ParameterSetName = 'InstallerCsv', Mandatory)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "Installer CSV file '$_' was not found."
        }
        return $true
    })]
    [string] $InstallerCsvPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PackageOutputDirectory,

    [Parameter(Mandatory)]
    [ValidatePattern('^CN=')]
    [string] $PublisherName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PublisherDisplayName,

    [Parameter()]
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')]
    [string] $Version = '1.0.0.0',

    [Parameter()]
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-PackageIdentityName {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $clean = $Name -replace '[^A-Za-z0-9.]', ''
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return 'ContosoApp'
    }

    return $clean
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter()]
        [string] $DefaultValue
    )

    if ($InputObject.PSObject.Properties.Name -contains $Name -and -not [string]::IsNullOrWhiteSpace($InputObject.$Name)) {
        return $InputObject.$Name
    }

    return $DefaultValue
}

function ConvertTo-ConversionTemplateDocument {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Item,

        [Parameter(Mandatory)]
        [string] $TemplatePath,

        [Parameter(Mandatory)]
        [string] $MsixPath,

        [Parameter(Mandatory)]
        [string] $TemplatePublisherName,

        [Parameter(Mandatory)]
        [string] $TemplatePublisherDisplayName,

        [Parameter(Mandatory)]
        [string] $DefaultVersion
    )

    $sourcePath = Get-PropertyValue -InputObject $Item -Name 'InstallerPath' -DefaultValue (Get-PropertyValue -InputObject $Item -Name 'PackagePath')
    $rawPackageName = Get-PropertyValue -InputObject $Item -Name 'PackageName' -DefaultValue (Get-PropertyValue -InputObject $Item -Name 'ApplicationName' -DefaultValue ([System.IO.Path]::GetFileNameWithoutExtension($sourcePath)))
    $packageName = ConvertTo-PackageIdentityName -Name $rawPackageName
    $packageVersion = Get-PropertyValue -InputObject $Item -Name 'Version' -DefaultValue $DefaultVersion
    $displayName = Get-PropertyValue -InputObject $Item -Name 'PackageDisplayName' -DefaultValue (Get-PropertyValue -InputObject $Item -Name 'ApplicationName' -DefaultValue $rawPackageName)
    $publisherNameForItem = Get-PropertyValue -InputObject $Item -Name 'PublisherName' -DefaultValue $TemplatePublisherName
    $publisherDisplayNameForItem = Get-PropertyValue -InputObject $Item -Name 'PublisherDisplayName' -DefaultValue $TemplatePublisherDisplayName

    $document = [System.Xml.XmlDocument]::new()
    $namespace = 'http://schemas.microsoft.com/appx/msixpackagingtool/template/2018'
    $root = $document.CreateElement('MsixPackagingToolTemplate', $namespace)
    $root.SetAttribute('xmlns:V2', 'http://schemas.microsoft.com/msix/msixpackagingtool/template/1904')
    $root.SetAttribute('xmlns:V3', 'http://schemas.microsoft.com/msix/msixpackagingtool/template/1907')
    $root.SetAttribute('xmlns:V4', 'http://schemas.microsoft.com/msix/msixpackagingtool/template/1910')
    $root.SetAttribute('xmlns:V5', 'http://schemas.microsoft.com/msix/msixpackagingtool/template/2001')
    $document.AppendChild($root) | Out-Null

    $settings = $document.CreateElement('Settings', $namespace)
    $settings.SetAttribute('AllowTelemetry', 'false')
    $settings.SetAttribute('ApplyAllPrepareComputerFixes', 'true')
    $settings.SetAttribute('GenerateCommandLineFile', 'true')
    $settings.SetAttribute('AllowPromptForPassword', 'false')
    $settings.SetAttribute('EnforceMicrosoftStoreVersioningRequirements', 'false')
    $root.AppendChild($settings) | Out-Null

    $saveLocation = $document.CreateElement('SaveLocation', $namespace)
    $saveLocation.SetAttribute('PackagePath', $MsixPath)
    $saveLocation.SetAttribute('TemplatePath', $TemplatePath)
    $root.AppendChild($saveLocation) | Out-Null

    $installer = $document.CreateElement('Installer', $namespace)
    $installer.SetAttribute('Path', $sourcePath)
    $installerArguments = Get-PropertyValue -InputObject $Item -Name 'InstallerArguments'
    if (-not [string]::IsNullOrWhiteSpace($installerArguments)) {
        $installer.SetAttribute('Arguments', $installerArguments)
    }
    $installLocation = Get-PropertyValue -InputObject $Item -Name 'InstallLocation'
    if (-not [string]::IsNullOrWhiteSpace($installLocation)) {
        $installer.SetAttribute('InstallLocation', $installLocation)
    }
    $root.AppendChild($installer) | Out-Null

    $packageInformation = $document.CreateElement('PackageInformation', $namespace)
    $packageInformation.SetAttribute('PackageName', $packageName)
    $packageInformation.SetAttribute('PackageDisplayName', $displayName)
    $packageInformation.SetAttribute('PublisherName', $publisherNameForItem)
    $packageInformation.SetAttribute('PublisherDisplayName', $publisherDisplayNameForItem)
    $packageInformation.SetAttribute('Version', $packageVersion)
    $root.AppendChild($packageInformation) | Out-Null

    return $document
}

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Create template output directory')) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $PackageOutputDirectory -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($PackageOutputDirectory, 'Create package output directory')) {
        New-Item -Path $PackageOutputDirectory -ItemType Directory -Force | Out-Null
    }
}

$items = if ($PSCmdlet.ParameterSetName -eq 'InstallerCsv') {
    @(Import-Csv -LiteralPath $InstallerCsvPath)
}
else {
    @(Get-Content -LiteralPath $InventoryJsonPath -Raw | ConvertFrom-Json)
}

foreach ($item in $items) {
    $sourcePath = Get-PropertyValue -InputObject $item -Name 'InstallerPath' -DefaultValue (Get-PropertyValue -InputObject $item -Name 'PackagePath')
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        throw 'Each input row must include PackagePath or InstallerPath.'
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
    $templatePath = Get-PropertyValue -InputObject $item -Name 'TemplateOutputPath' -DefaultValue (Join-Path -Path $OutputDirectory -ChildPath "$baseName.template.xml")
    $msixPath = Get-PropertyValue -InputObject $item -Name 'PackageOutputPath' -DefaultValue (Join-Path -Path $PackageOutputDirectory -ChildPath "$baseName.msix")

    if ((Test-Path -LiteralPath $templatePath) -and -not $Force.IsPresent) {
        throw "Template '$templatePath' already exists. Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($templatePath, 'Create MSIX conversion template')) {
        $document = ConvertTo-ConversionTemplateDocument -Item $item -TemplatePath $templatePath -MsixPath $msixPath -TemplatePublisherName $PublisherName -TemplatePublisherDisplayName $PublisherDisplayName -DefaultVersion $Version
        $document.Save($templatePath)
    }

    [pscustomobject]@{
        SourcePackage = $sourcePath
        TemplatePath = $templatePath
        PackagePath = $msixPath
        LearnReferences = @(
            'https://learn.microsoft.com/windows/msix/packaging-tool/generate-template-file'
            'https://learn.microsoft.com/windows/msix/packaging-tool/create-app-package'
        )
    }
}
