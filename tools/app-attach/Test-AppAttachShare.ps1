<#
.SYNOPSIS
Checks Azure Files readiness for App Attach.

.DESCRIPTION
Performs read-only checks for an Azure Files share intended for App Attach with Microsoft Entra joined Azure Virtual Desktop session hosts. The script checks that the storage account and file share are visible, whether Microsoft Entra Kerberos is enabled on the storage account, and whether the documented Reader and Data Access role assignments are present for the Azure Virtual Desktop and Azure Virtual Desktop ARM Provider service principals at or above the storage account scope.

This script does not create or change Azure resources.

.PARAMETER ResourceGroupName
The resource group that contains the storage account.

.PARAMETER StorageAccountName
The storage account name.

.PARAMETER ShareName
The Azure Files share name.

.PARAMETER SubscriptionId
Optional subscription ID, used only to build the expected storage account scope in output.

.EXAMPLE
.\Test-AppAttachShare.ps1 -ResourceGroupName rg-avd-storage -StorageAccountName contosoapps -ShareName appattach

Checks a share in the current Azure context.

.EXAMPLE
.\Test-AppAttachShare.ps1 -ResourceGroupName rg-avd-storage -StorageAccountName contosoapps -ShareName appattach -SubscriptionId 00000000-0000-0000-0000-000000000000

Checks a share and emits a storage account scope that includes the supplied subscription ID.

.NOTES
Sources:
https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup
https://learn.microsoft.com/azure/virtual-desktop/app-attach-overview
https://learn.microsoft.com/azure/virtual-desktop/service-principal-assign-roles
https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable
https://learn.microsoft.com/powershell/module/az.storage/get-azstorageaccount
https://learn.microsoft.com/powershell/module/az.storage/get-azstorageshare
https://learn.microsoft.com/powershell/module/az.resources/get-azadserviceprincipal
https://learn.microsoft.com/powershell/module/az.resources/get-azroleassignment

.LINK
https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $StorageAccountName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ShareName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SubscriptionId
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
            throw "Required command '$commandName' was not found. Install the documented Az module before running this script."
        }
    }
}

Assert-CommandAvailable -Name @('Get-AzStorageAccount', 'Get-AzStorageShare', 'Get-AzADServicePrincipal', 'Get-AzRoleAssignment')

$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
$share = Get-AzStorageShare -Name $ShareName -Context $storageAccount.Context -ErrorAction Stop
$scope = $storageAccount.Id
if ([string]::IsNullOrWhiteSpace($scope) -and -not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
    $scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
}

$servicePrincipals = @(
    [pscustomobject]@{
        Name = 'Azure Virtual Desktop'
        ApplicationId = '9cdead84-a844-4324-93f2-b2e6bb768d07'
    }
    [pscustomobject]@{
        Name = 'Azure Virtual Desktop ARM Provider'
        ApplicationId = '50e95039-b200-4007-bc97-8d5790743a63'
    }
)

$roleFindings = foreach ($principal in $servicePrincipals) {
    $servicePrincipal = Get-AzADServicePrincipal -ApplicationId $principal.ApplicationId
    $assignments = if ($null -eq $servicePrincipal) {
        @()
    }
    else {
        @(Get-AzRoleAssignment -ObjectId $servicePrincipal.Id -RoleDefinitionName 'Reader and Data Access' -Scope $scope -ErrorAction SilentlyContinue)
    }

    [pscustomobject]@{
        ServicePrincipal = $principal.Name
        ApplicationId = $principal.ApplicationId
        RequiredRole = 'Reader and Data Access'
        Scope = $scope
        ObjectId = if ($null -eq $servicePrincipal) { $null } else { $servicePrincipal.Id }
        AssignmentFound = $assignments.Count -gt 0
        AssignmentCount = $assignments.Count
    }
}

[pscustomobject]@{
    StorageAccountName = $StorageAccountName
    ResourceGroupName = $ResourceGroupName
    ShareName = $ShareName
    ShareExists = $null -ne $share
    StorageAccountScope = $scope
    MicrosoftEntraKerberosEnabled = [bool]$storageAccount.EnableAzureActiveDirectoryKerberosForFile
    RoleAssignments = @($roleFindings)
    LearnRequirement = 'For Microsoft Entra joined session hosts using Azure Files, Microsoft Learn requires Reader and Data Access for both Azure Virtual Desktop and Azure Virtual Desktop ARM Provider service principals, with the storage account in the same subscription as the session host VMs.'
    LearnReferences = @(
        'https://learn.microsoft.com/azure/virtual-desktop/app-attach-setup'
        'https://learn.microsoft.com/azure/virtual-desktop/service-principal-assign-roles'
        'https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable'
    )
}
