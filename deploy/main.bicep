targetScope = 'resourceGroup'

@description('Short prefix used for resource names. Use lower-case letters, numbers and hyphens.')
@minLength(3)
@maxLength(18)
param workloadPrefix string = 'contoso-avd'

@description('Azure region for the pilot environment. The portal Basics step supplies this value.')
param location string = resourceGroup().location

@description('Microsoft Entra group object ID for pilot users.')
param pilotUsersGroupObjectId string

@description('Local administrator username stored in Key Vault and referenced by the session host configuration.')
@secure()
param localAdminUsername string

@description('Local administrator password stored in Key Vault and referenced by the session host configuration.')
@secure()
param localAdminPassword string

@description('Create a new virtual network or use an existing session host subnet.')
@allowed([
  'new'
  'existing'
])
param networkMode string = 'new'

@description('Resource ID of an existing subnet for session hosts. Required when networkMode is existing.')
param existingSubnetResourceId string = ''

@description('Address prefix for the new virtual network.')
param vnetAddressPrefix string = '10.60.0.0/16'

@description('Address prefix for the new session host subnet.')
param sessionHostSubnetPrefix string = '10.60.1.0/24'

@description('Enable an Azure Files private endpoint and privatelink.file.core.windows.net private DNS zone.')
param enableFilesPrivateEndpoint bool = true

@description('Assign subscription-scope autoscale roles to the new host pool managed identity. Leave enabled unless a subscription Owner or User Access Administrator will assign them manually before scaling runs.')
param assignAutoscaleRolesToHostPoolIdentity bool = true

@description('Assign subscription-scope autoscale roles to the Azure Virtual Desktop service principal when azureVirtualDesktopServicePrincipalObjectId is supplied. Default false because many tenants already have these assignments.')
param assignAutoscaleRolesToAvdServicePrincipal bool = false

@description('Azure Virtual Desktop service principal object ID in this tenant. Recommended for dynamic autoscaling subscription-scope role assignments. Find it from application ID 9cdead84-a844-4324-93f2-b2e6bb768d07.')
param azureVirtualDesktopServicePrincipalObjectId string = ''

@description('Azure Virtual Desktop ARM Provider service principal object ID in this tenant. Required when assigning Reader and Data Access for App Attach on Azure Files.')
param azureVirtualDesktopArmProviderServicePrincipalObjectId string = ''

@description('Host pool metadata deployment scope. Geographical is the standard behaviour and works in every AVD region. Regional is available only in supported regions.')
@allowed([
  'Geographical'
  'Regional'
])
param hostPoolDeploymentScope string = 'Geographical'

@description('Virtual machine size for session hosts. Curated to v5 sizes with temp disk placement large enough for the 127 GiB Windows 11 Enterprise multi-session image plus Trusted launch VM guest state.')
@allowed([
  'Standard_D4ads_v5'
  'Standard_D8ads_v5'
  'Standard_D16ads_v5'
  'Standard_D4ds_v5'
  'Standard_D8ds_v5'
  'Standard_D16ds_v5'
  'Standard_E8ads_v5'
])
param sessionHostVmSize string = 'Standard_D8ads_v5'

@description('Session host computer name prefix. Azure Virtual Desktop limits this to 11 characters.')
@minLength(1)
@maxLength(11)
param sessionHostNamePrefix string = 'ctavd'

@description('Maximum sessions per session host. Validate this through a pilot before production.')
@minValue(1)
@maxValue(40)
param maxSessionLimit int = 12

@description('Windows 11 Enterprise multi-session image family.')
@allowed([
  'win11-26h2-avd'
  'win11-26h2-avd-m365'
])
param marketplaceImageSku string = 'win11-26h2-avd-m365'

@description('Marketplace image offer for the selected image.')
@allowed([
  'Windows-11'
  'office-365'
])
param marketplaceImageOffer string = 'office-365'

@description('Marketplace image publisher.')
param marketplaceImagePublisher string = 'MicrosoftWindowsDesktop'

@description('Exact Marketplace image version. Get the newest version with: az vm image list -l <region> -p MicrosoftWindowsDesktop -f <offer> -s <sku> --all --query "[-1].version" -o tsv, or Get-AzVMImage with Location, PublisherName, Offer and Skus.')
param marketplaceImageVersion string

@description('Enrol session hosts in Microsoft Intune as they are created. Keep true for the North Star. The tenant needs Intune licences and automatic MDM enrolment configured, or session host provisioning fails with MdmJoinFailed. Set false only for a lab without Intune.')
param enrollSessionHostsInIntune bool = true

@description('Availability zones for session hosts. Leave empty in regions or subscriptions where the selected VM size does not support zones.')
param availabilityZones array = [
  1
  2
  3
]

@description('Windows time zone ID for the scaling plan.')
param scalingTimeZone string = 'AUS Eastern Standard Time'

@description('Minimum host pool size used during ramp-up and peak.')
@minValue(0)
@maxValue(59)
param rampUpMinimumHostPoolSize int = 2

@description('Maximum host pool size used during ramp-up and peak.')
@minValue(1)
@maxValue(59)
param rampUpMaximumHostPoolSize int = 4

@description('Minimum host pool size used during ramp-down and off-peak.')
@minValue(0)
@maxValue(59)
param rampDownMinimumHostPoolSize int = 0

@description('Maximum host pool size used during ramp-down and off-peak.')
@minValue(1)
@maxValue(59)
param rampDownMaximumHostPoolSize int = 2

@description('Tags applied to deployable resources.')
param tags object = {
  workload: 'avd-north-star'
  environment: 'pilot'
  owner: 'contoso'
}

var safePrefix = toLower(replace(workloadPrefix, '-', ''))
var namePrefix = take(safePrefix, 16)
var identityName = '${namePrefix}-hp-mi'
var workspaceName = '${namePrefix}-law'
var hostPoolName = '${namePrefix}-hp'
var appGroupName = '${namePrefix}-dag'
var avdWorkspaceName = '${namePrefix}-ws'
var scalingPlanName = '${namePrefix}-sp'
var keyVaultName = take('${namePrefix}${uniqueString(resourceGroup().id)}kv', 24)
var storageAccountName = take('${namePrefix}${uniqueString(resourceGroup().id)}st', 24)
var desktopVirtualizationPowerOnOffContributorRoleId = '40c5ff49-9181-41f8-ae61-143b0e78555e'
var desktopVirtualizationVirtualMachineContributorRoleId = 'a959dbd1-f747-45e3-8ba6-dd80f235f97c'

resource hostPoolIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = if (networkMode == 'new') {
  name: 'network'
  params: {
    location: location
    workloadPrefix: namePrefix
    vnetAddressPrefix: vnetAddressPrefix
    sessionHostSubnetPrefix: sessionHostSubnetPrefix
    tags: tags
  }
}

var sessionHostSubnetId = networkMode == 'new' ? network!.outputs.sessionHostSubnetId : existingSubnetResourceId

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    workspaceName: workspaceName
    tags: tags
  }
}

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    keyVaultName: keyVaultName
    localAdminUsername: localAdminUsername
    localAdminPassword: localAdminPassword
    hostPoolIdentityPrincipalId: hostPoolIdentity.properties.principalId
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageAccountName: storageAccountName
    pilotUsersGroupObjectId: pilotUsersGroupObjectId
    azureVirtualDesktopServicePrincipalObjectId: azureVirtualDesktopServicePrincipalObjectId
    azureVirtualDesktopArmProviderServicePrincipalObjectId: azureVirtualDesktopArmProviderServicePrincipalObjectId
    enableFilesPrivateEndpoint: enableFilesPrivateEndpoint
    privateEndpointSubnetId: sessionHostSubnetId
    tags: tags
  }
}

module avd 'modules/avd.bicep' = {
  name: 'avd'
  params: {
    location: location
    hostPoolName: hostPoolName
    hostPoolDeploymentScope: hostPoolDeploymentScope
    appGroupName: appGroupName
    workspaceName: avdWorkspaceName
    scalingPlanName: scalingPlanName
    hostPoolIdentityResourceId: hostPoolIdentity.id
    sessionHostNamePrefix: sessionHostNamePrefix
    sessionHostVmSize: sessionHostVmSize
    maxSessionLimit: maxSessionLimit
    subnetId: sessionHostSubnetId
    localAdminUsernameSecretUri: keyVault.outputs.localAdminUsernameSecretUri
    localAdminPasswordSecretUri: keyVault.outputs.localAdminPwdSecretUri
    marketplaceImagePublisher: marketplaceImagePublisher
    marketplaceImageOffer: marketplaceImageOffer
    marketplaceImageSku: marketplaceImageSku
    marketplaceImageVersion: marketplaceImageVersion
    enrollSessionHostsInIntune: enrollSessionHostsInIntune
    availabilityZones: availabilityZones
    scalingTimeZone: scalingTimeZone
    rampUpMinimumHostPoolSize: rampUpMinimumHostPoolSize
    rampUpMaximumHostPoolSize: rampUpMaximumHostPoolSize
    rampDownMinimumHostPoolSize: rampDownMinimumHostPoolSize
    rampDownMaximumHostPoolSize: rampDownMaximumHostPoolSize
    pilotUsersGroupObjectId: pilotUsersGroupObjectId
    hostPoolIdentityPrincipalId: hostPoolIdentity.properties.principalId
    virtualMachineContributorRoleDefinitionId: desktopVirtualizationVirtualMachineContributorRoleId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags: tags
  }
}

module subscriptionRoles 'modules/subscription-role-assignments.bicep' = if (assignAutoscaleRolesToHostPoolIdentity || (assignAutoscaleRolesToAvdServicePrincipal && !empty(azureVirtualDesktopServicePrincipalObjectId))) {
  name: 'subscription-avd-autoscale-roles'
  scope: subscription()
  params: {
    hostPoolManagedIdentityPrincipalId: hostPoolIdentity.properties.principalId
    azureVirtualDesktopServicePrincipalObjectId: azureVirtualDesktopServicePrincipalObjectId
    assignAutoscaleRolesToHostPoolIdentity: assignAutoscaleRolesToHostPoolIdentity
    assignAutoscaleRolesToAvdServicePrincipal: assignAutoscaleRolesToAvdServicePrincipal
    powerOnOffContributorRoleDefinitionId: desktopVirtualizationPowerOnOffContributorRoleId
    virtualMachineContributorRoleDefinitionId: desktopVirtualizationVirtualMachineContributorRoleId
  }
}

output hostPoolName string = avd.outputs.hostPoolName
output workspaceName string = avd.outputs.workspaceName
output desktopApplicationGroupName string = avd.outputs.desktopApplicationGroupName
output scalingPlanName string = avd.outputs.scalingPlanName
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName
output hostPoolManagedIdentityPrincipalId string = hostPoolIdentity.properties.principalId
output profilesSharePath string = '\\\\${storage.outputs.storageAccountName}.file.${environment().suffixes.storage}\\${storage.outputs.profilesShareName}'
output appAttachSharePath string = '\\\\${storage.outputs.storageAccountName}.file.${environment().suffixes.storage}\\${storage.outputs.appAttachShareName}'
output postDeploymentSteps array = [
  'Enable Microsoft Entra Kerberos authentication for Azure Files if tenant admin consent and storage identity configuration are not already complete.'
  'Set directory and file level permissions on the profiles share so each user can access only their own FSLogix container.'
  'Configure Intune Settings Catalog policy Kerberos/CloudKerberosTicketRetrievalEnabled = 1 and FSLogix profile settings including VHDLocations.'
  'Enable Microsoft Entra authentication for RDP and configure Conditional Access for Azure Virtual Desktop and Windows Cloud Login.'
  'Pin an exact Marketplace image version. Do not use latest for session host configuration. Get the newest version with az vm image list -l <region> -p MicrosoftWindowsDesktop -f <offer> -s <sku> --all --query "[-1].version" -o tsv, or Get-AzVMImage with Location, PublisherName, Offer and Skus.'
  'Confirm App Attach package signing, package placement on the appattach share and app group assignment after the first session host is available.'
  'Dynamic autoscaling creates the session hosts. Confirm Desktop Virtualization Power On Off Contributor and Desktop Virtualization Virtual Machine Contributor exist at subscription scope for the host pool managed identity before expecting hosts to appear.'
  'Microsoft Learn also names the Azure Virtual Desktop service principal for dynamic autoscaling. Many tenants already have these assignments. If hosts are not created, check whether the service principal with application ID 9cdead84-a844-4324-93f2-b2e6bb768d07 has both roles at subscription scope, then assign any missing role.'
]
