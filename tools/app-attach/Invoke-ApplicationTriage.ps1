<#
.SYNOPSIS
Classifies image inventory rows for App Attach migration planning.

.DESCRIPTION
Applies an editable JSON rule set to application inventory from Get-ImageApplicationInventory.ps1. Rules are regular expressions over application name, publisher, path and source type. The first matching rule wins.

The default rules are intentionally conservative. They keep platform runtimes and agents in the base image, send existing App-V packages to AppAttachAppV, flag drivers and services for review, and treat remaining applications as AppAttachMsix candidates.

.PARAMETER InputPath
Path to CSV or JSON inventory input.

.PARAMETER RulesPath
Path to the editable triage-rules.json file.

.PARAMETER CsvPath
Optional CSV export path.

.PARAMETER JsonPath
Optional JSON export path.

.EXAMPLE
.\Invoke-ApplicationTriage.ps1 -InputPath .\image-inventory.json -RulesPath .\triage-rules.json

Classifies JSON inventory with the default rules.

.EXAMPLE
.\Invoke-ApplicationTriage.ps1 -InputPath .\image-inventory.csv -RulesPath .\triage-rules.json -CsvPath .\triage.csv -JsonPath .\triage.json

Classifies CSV inventory and writes both exports.

.NOTES
Sources:
https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare
https://learn.microsoft.com/windows/msix/packaging-tool/tool-known-issues
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview

.LINK
https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "Input file '$_' was not found."
        }
        return $true
    })]
    [string] $InputPath,

    [Parameter(Mandatory)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "Rules file '$_' was not found."
        }
        return $true
    })]
    [string] $RulesPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $CsvPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $JsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-InputItem {
    param(
        [Parameter(Mandatory)]
        [string] $SourcePath
    )

    if ($SourcePath -match '\.json$') {
        return @(Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json)
    }

    return @(Import-Csv -LiteralPath $SourcePath)
}

function Get-ObjectValue {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $Names
    )

    foreach ($name in $Names) {
        if ($InputObject.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace($InputObject.$name)) {
            return [string]$InputObject.$name
        }
    }

    return ''
}

function Test-RuleMatch {
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Rule,

        [Parameter(Mandatory)]
        [pscustomobject] $Item
    )

    $checks = @{
        name = Get-ObjectValue -InputObject $Item -Names @('DisplayName', 'Name', 'ApplicationName', 'PackageName', 'ServiceName', 'DriverName')
        publisher = Get-ObjectValue -InputObject $Item -Names @('Publisher', 'Manufacturer', 'CompanyName')
        path = Get-ObjectValue -InputObject $Item -Names @('InstallLocation', 'InstallSource', 'PathName', 'ImagePath', 'PackagePath', 'SourcePath')
        sourceType = Get-ObjectValue -InputObject $Item -Names @('SourceType', 'InventoryType')
    }

    foreach ($field in @('name', 'publisher', 'path', 'sourceType')) {
        if ($Rule.PSObject.Properties.Name -contains $field -and -not [string]::IsNullOrWhiteSpace($Rule.$field)) {
            if ($checks[$field] -notmatch $Rule.$field) {
                return $false
            }
        }
    }

    return $true
}

$rulesDocument = Get-Content -LiteralPath $RulesPath -Raw | ConvertFrom-Json
$items = Get-InputItem -SourcePath $InputPath

$result = foreach ($item in $items) {
    $matchedRule = $null
    foreach ($rule in $rulesDocument.rules) {
        if (Test-RuleMatch -Rule $rule -Item $item) {
            $matchedRule = $rule
            break
        }
    }

    $category = if ($null -eq $matchedRule) { 'AppAttachMsix' } else { $matchedRule.category }
    $reason = if ($null -eq $matchedRule) { 'No rule matched. Defaulted to AppAttachMsix candidate for source repackaging.' } else { $matchedRule.reason }

    [pscustomobject]@{
        Name = Get-ObjectValue -InputObject $item -Names @('DisplayName', 'Name', 'ApplicationName', 'PackageName', 'ServiceName', 'DriverName')
        Publisher = Get-ObjectValue -InputObject $item -Names @('Publisher', 'Manufacturer', 'CompanyName')
        Version = Get-ObjectValue -InputObject $item -Names @('DisplayVersion', 'Version', 'PackageVersion')
        Path = Get-ObjectValue -InputObject $item -Names @('InstallLocation', 'InstallSource', 'PathName', 'ImagePath', 'PackagePath', 'SourcePath')
        SourceType = Get-ObjectValue -InputObject $item -Names @('SourceType', 'InventoryType')
        Recommendation = $category
        Reason = $reason
        LearnReferences = @(
            'https://learn.microsoft.com/windows/msix/desktop/desktop-to-uwp-prepare'
            'https://learn.microsoft.com/windows/msix/packaging-tool/tool-known-issues'
            'https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview'
        )
        Original = $item
    }
}

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $result | Select-Object Name, Publisher, Version, Path, SourceType, Recommendation, Reason | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $JsonPath -Encoding utf8
}

$result
