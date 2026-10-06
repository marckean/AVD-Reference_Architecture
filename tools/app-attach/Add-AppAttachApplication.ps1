<#
.SYNOPSIS
Adds App Attach packages and assigns them to host pools and groups.

.DESCRIPTION
Wraps the Microsoft Learn Azure PowerShell flow for App Attach: Import-AzWvdAppAttachPackageInfo reads package metadata, New-AzWvdAppAttachPackage creates the package, Update-AzWvdAppAttachPackage assigns host pools, and New-AzRoleAssignment grants groups the Desktop Virtualization User role on the package scope.

The script supports single-package onboarding or CSV bulk onboarding. It accepts only App Attach package inputs documented by Microsoft Learn: MSIX or Appx disk images in CimFS, VHDX, or VHD format, and App-V packages.

.PARAMETER ResourceGroupName
The resource group that contains the App Attach package resource.

.PARAMETER Location
The Azure region for the App Attach package.

.PARAMETER HostPoolName
The host pool used by Import-AzWvdAppAttachPackageInfo to read package metadata. Learn says this can be any host pool where session hosts have access to the file share.

.PARAMETER PackagePath
The UNC path to a CimFS, VHDX, VHD, or App-V package file.

.PARAMETER Name
The App Attach package resource name.

.PARAMETER DisplayName
The friendly display name for the package.

.PARAMETER SubscriptionId
Optional Azure subscription ID.

.PARAMETER PackageFullName
Optional package full name filter when Import-AzWvdAppAttachPackageInfo returns more than one object.

.PARAMETER HostPoolResourceId
One or more host pool resource IDs to assign. Microsoft Learn states the host pool list overwrites existing host pool assignments.

.PARAMETER GroupObjectId
One or more Microsoft Entra group object IDs to assign with the Desktop Virtualization User role.

.PARAMETER CsvPath
CSV input for bulk onboarding. Supported columns are ResourceGroupName, Location, HostPoolName, PackagePath, Name, DisplayName, SubscriptionId, PackageFullName, HostPoolResourceId, and GroupObjectId. Multiple IDs use semicolons.

.PARAMETER FailHealthCheckOnStagingFailure
The status to use when staging fails. Az.DesktopVirtualization 6.0.0 offers Unhealthy, NeedsAssistance and DoNotFail. The Microsoft Learn setup example uses NeedsAssistance.

.PARAMETER PassThru
Returns the created or updated package object when supported by the Az.DesktopVirtualization cmdlets.

.EXAMPLE
.\Add-AppAttachApplication.ps1 -ResourceGroupName rg-avd-apps -Location australiaeast -HostPoolName hp-pooled -PackagePath \\contoso.file.core.windows.net\apps\Notepad.cim -Name contoso-notepad -DisplayName "Contoso Notepad" -HostPoolResourceId /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-avd/providers/Microsoft.DesktopVirtualization/hostPools/hp-pooled -GroupObjectId 11111111-1111-1111-1111-111111111111 -WhatIf

Shows the create and assignment operations without changing Azure.

.EXAMPLE
.\Add-AppAttachApplication.ps1 -CsvPath .\apps.csv -WhatIf

Runs bulk onboarding in WhatIf mode.

.NOTES
Sources:
https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview
https://learn.microsoft.com/powershell/module/az.desktopvirtualization/import-azwvdappattachpackageinfo
https://learn.microsoft.com/powershell/module/az.desktopvirtualization/new-azwvdappattachpackage
https://learn.microsoft.com/powershell/module/az.desktopvirtualization/update-azwvdappattachpackage
https://learn.microsoft.com/powershell/module/az.resources/new-azroleassignment

.LINK
https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Location,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $HostPoolName,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [ValidateScript({
        if ($_ -notmatch '\.(cim|vhdx|vhd|appv)$') {
            throw 'PackagePath must end with .cim, .vhdx, .vhd, or .appv.'
        }
        return $true
    })]
    [string] $PackagePath,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string] $DisplayName,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string] $SubscriptionId,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string] $PackageFullName,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string[]] $HostPoolResourceId,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateNotNullOrEmpty()]
    [string[]] $GroupObjectId,

    [Parameter(ParameterSetName = 'Csv', Mandatory)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "CSV file '$_' was not found."
        }
        return $true
    })]
    [string] $CsvPath,

    [Parameter()]
    [ValidateSet('Unhealthy', 'NeedsAssistance', 'DoNotFail')]
    [string] $FailHealthCheckOnStagingFailure = 'NeedsAssistance',

    [Parameter()]
    [switch] $PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-CommandAvailable {
    param(
        [Parameter(Mandatory)]
        [string[]] $Name
    )

    foreach ($commandName in $Name) {
        if ($null -eq (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            throw "Required command '$commandName' was not found. Install the documented Az modules before running this script."
        }
    }
}

function Split-Cell {
    param(
        [Parameter()]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Invoke-AppAttachOnboarding {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Item,

        [Parameter(Mandatory)]
        [string] $FailureStatus,

        [Parameter()]
        [switch] $ReturnPackage
    )

    $normalisedItem = [pscustomobject]@{
        ResourceGroupName = if ($Item.PSObject.Properties.Name -contains 'ResourceGroupName') { $Item.ResourceGroupName } else { $null }
        Location = if ($Item.PSObject.Properties.Name -contains 'Location') { $Item.Location } else { $null }
        HostPoolName = if ($Item.PSObject.Properties.Name -contains 'HostPoolName') { $Item.HostPoolName } else { $null }
        PackagePath = if ($Item.PSObject.Properties.Name -contains 'PackagePath') { $Item.PackagePath } else { $null }
        Name = if ($Item.PSObject.Properties.Name -contains 'Name') { $Item.Name } else { $null }
        DisplayName = if ($Item.PSObject.Properties.Name -contains 'DisplayName') { $Item.DisplayName } else { $null }
        SubscriptionId = if ($Item.PSObject.Properties.Name -contains 'SubscriptionId') { $Item.SubscriptionId } else { $null }
        PackageFullName = if ($Item.PSObject.Properties.Name -contains 'PackageFullName') { $Item.PackageFullName } else { $null }
        HostPoolResourceId = if ($Item.PSObject.Properties.Name -contains 'HostPoolResourceId') { $Item.HostPoolResourceId } else { $null }
        GroupObjectId = if ($Item.PSObject.Properties.Name -contains 'GroupObjectId') { $Item.GroupObjectId } else { $null }
    }

    foreach ($requiredColumn in @('ResourceGroupName', 'Location', 'HostPoolName', 'PackagePath', 'Name')) {
        if ([string]::IsNullOrWhiteSpace($normalisedItem.$requiredColumn)) {
            throw "The onboarding item is missing required value '$requiredColumn'."
        }
    }

    $importParameters = @{
        HostPoolName = $normalisedItem.HostPoolName
        ResourceGroupName = $normalisedItem.ResourceGroupName
        Path = $normalisedItem.PackagePath
    }
    if (-not [string]::IsNullOrWhiteSpace($normalisedItem.SubscriptionId)) {
        $importParameters.SubscriptionId = $normalisedItem.SubscriptionId
    }

    Write-Verbose "Reading package metadata for '$($normalisedItem.PackagePath)'."
    $packageInfo = @(Import-AzWvdAppAttachPackageInfo @importParameters)
    if (-not [string]::IsNullOrWhiteSpace($normalisedItem.PackageFullName)) {
        $packageInfo = @($packageInfo | Where-Object { $_.ImagePackageFullName -like "*$($normalisedItem.PackageFullName)*" })
    }

    if ($packageInfo.Count -ne 1) {
        throw "Expected one package metadata object for '$($normalisedItem.PackagePath)', but found $($packageInfo.Count). Use PackageFullName to select one package."
    }

    $createParameters = @{
        AppAttachPackage = $packageInfo[0]
        Name = $normalisedItem.Name
        ResourceGroupName = $normalisedItem.ResourceGroupName
        Location = $normalisedItem.Location
        FailHealthCheckOnStagingFailure = $FailureStatus
        ImageIsActive = $true
        ImageIsRegularRegistration = $false
    }
    if (-not [string]::IsNullOrWhiteSpace($normalisedItem.SubscriptionId)) {
        $createParameters.SubscriptionId = $normalisedItem.SubscriptionId
    }
    if (-not [string]::IsNullOrWhiteSpace($normalisedItem.DisplayName)) {
        $createParameters.ImageDisplayName = $normalisedItem.DisplayName
    }
    if ($ReturnPackage.IsPresent) {
        $createParameters.PassThru = $true
    }

    $createdPackage = $null
    if ($PSCmdlet.ShouldProcess($normalisedItem.Name, 'Create App Attach package')) {
        $createdPackage = New-AzWvdAppAttachPackage @createParameters
    }

    $hostPoolReferences = @(Split-Cell -Value $normalisedItem.HostPoolResourceId)
    if ($hostPoolReferences.Count -gt 0) {
        $updateParameters = @{
            Name = $normalisedItem.Name
            ResourceGroupName = $normalisedItem.ResourceGroupName
            HostPoolReference = $hostPoolReferences
        }
        # Learn's example (written against Az.DesktopVirtualization 4.2.1) passes Location to
        # Update-AzWvdAppAttachPackage, but newer module versions (6.0.0) don't accept it.
        if ((Get-Command -Name Update-AzWvdAppAttachPackage).Parameters.ContainsKey('Location')) {
            $updateParameters.Location = $normalisedItem.Location
        }
        if (-not [string]::IsNullOrWhiteSpace($normalisedItem.SubscriptionId)) {
            $updateParameters.SubscriptionId = $normalisedItem.SubscriptionId
        }

        if ($PSCmdlet.ShouldProcess($normalisedItem.Name, 'Assign host pools to App Attach package')) {
            Update-AzWvdAppAttachPackage @updateParameters | Out-Null
            $createdPackage = $null
        }
    }

    $groupObjectIds = @(Split-Cell -Value $normalisedItem.GroupObjectId)
    $needPackage = ($groupObjectIds.Count -gt 0) -or $ReturnPackage.IsPresent
    if ($needPackage -and -not $WhatIfPreference -and ($null -eq $createdPackage -or [string]::IsNullOrWhiteSpace($createdPackage.Id))) {
        # Read the package back so role assignments use the real resource ID. Under -WhatIf the
        # package doesn't exist yet, so the assignments are only described.
        $getParameters = @{
            Name = $normalisedItem.Name
            ResourceGroupName = $normalisedItem.ResourceGroupName
        }
        if (-not [string]::IsNullOrWhiteSpace($normalisedItem.SubscriptionId)) {
            $getParameters.SubscriptionId = $normalisedItem.SubscriptionId
        }
        $createdPackage = Get-AzWvdAppAttachPackage @getParameters
    }

    $packageScope = if ($null -ne $createdPackage -and -not [string]::IsNullOrWhiteSpace($createdPackage.Id)) {
        $createdPackage.Id
    }
    else {
        "App Attach package '$($normalisedItem.Name)' in resource group '$($normalisedItem.ResourceGroupName)'"
    }

    foreach ($groupId in $groupObjectIds) {
        if ($PSCmdlet.ShouldProcess($groupId, "Assign Desktop Virtualization User on $packageScope")) {
            $null = New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName 'Desktop Virtualization User' -Scope $createdPackage.Id
        }
    }

    if ($ReturnPackage.IsPresent -and $null -ne $createdPackage) {
        $createdPackage
    }
}

Assert-CommandAvailable -Name @(
    'Import-AzWvdAppAttachPackageInfo'
    'New-AzWvdAppAttachPackage'
    'Update-AzWvdAppAttachPackage'
    'Get-AzWvdAppAttachPackage'
    'New-AzRoleAssignment'
)

$items = if ($PSCmdlet.ParameterSetName -eq 'Csv') {
    Import-Csv -LiteralPath $CsvPath
}
else {
    [pscustomobject]@{
        ResourceGroupName = $ResourceGroupName
        Location = $Location
        HostPoolName = $HostPoolName
        PackagePath = $PackagePath
        Name = $Name
        DisplayName = $DisplayName
        SubscriptionId = $SubscriptionId
        PackageFullName = $PackageFullName
        HostPoolResourceId = ($HostPoolResourceId -join ';')
        GroupObjectId = ($GroupObjectId -join ';')
    }
}

foreach ($item in $items) {
    Invoke-AppAttachOnboarding -Item $item -FailureStatus $FailHealthCheckOnStagingFailure -ReturnPackage:$PassThru.IsPresent -WhatIf:$WhatIfPreference
}
