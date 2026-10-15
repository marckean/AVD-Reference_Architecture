param location string
param storageAccountName string
param pilotUsersGroupObjectId string
param pilotPrincipalType string
param azureVirtualDesktopServicePrincipalObjectId string
param azureVirtualDesktopArmProviderServicePrincipalObjectId string
param enableFilesPrivateEndpoint bool
param filesPrivateDnsZoneMode string
param existingFilesPrivateDnsZoneId string
param filesPublicNetworkAccess string
param enableFilesEntraKerberos bool
param privateEndpointSubnetId string
param tags object

var storageFileDataSmbShareContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var readerAndDataAccessRoleId = 'c12c1c16-33a1-487b-954d-41c89c60f349'
var profilesShareName = 'profiles'
var appAttachShareName = 'appattach'
var privateEndpointVnetId = split(privateEndpointSubnetId, '/subnets/')[0]
var privateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
var createPrivateDnsZone = enableFilesPrivateEndpoint && filesPrivateDnsZoneMode == 'Create'
// ManagedByPolicy leaves the private endpoint without a DNS zone group, so a landing zone's
// DeployIfNotExists policy can add the record in its central privatelink zone.
var attachPrivateDnsZoneGroup = enableFilesPrivateEndpoint && filesPrivateDnsZoneMode != 'ManagedByPolicy'
var privateDnsZoneIdForGroup = filesPrivateDnsZoneMode == 'Existing' ? existingFilesPrivateDnsZoneId : resourceId('Microsoft.Network/privateDnsZones', privateDnsZoneName)

resource storage 'Microsoft.Storage/storageAccounts@2026-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: union({
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    // App Attach on Microsoft Entra joined hosts relies on the Reader and Data Access role, which reads the account keys.
    allowSharedKeyAccess: true
    publicNetworkAccess: filesPublicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enableFilesPrivateEndpoint ? 'Deny' : 'Allow'
    }
  }, enableFilesEntraKerberos ? {
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      defaultSharePermission: 'None'
    }
  } : {})
  tags: tags
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2026-06-01' = {
  parent: storage
  name: 'default'
}

resource profilesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2026-06-01' = {
  parent: fileService
  name: profilesShareName
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: 1024
  }
}

resource appAttachShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2026-06-01' = {
  parent: fileService
  name: appAttachShareName
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: 512
  }
}

resource usersProfilesContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(profilesShare.id, pilotUsersGroupObjectId, storageFileDataSmbShareContributorRoleId)
  scope: profilesShare
  properties: {
    principalId: pilotUsersGroupObjectId
    principalType: pilotPrincipalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageFileDataSmbShareContributorRoleId)
  }
}

resource avdReaderDataAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(azureVirtualDesktopServicePrincipalObjectId)) {
  name: guid(storage.id, azureVirtualDesktopServicePrincipalObjectId, readerAndDataAccessRoleId)
  scope: storage
  properties: {
    principalId: azureVirtualDesktopServicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerAndDataAccessRoleId)
  }
}

resource avdArmProviderReaderDataAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(azureVirtualDesktopArmProviderServicePrincipalObjectId)) {
  name: guid(storage.id, azureVirtualDesktopArmProviderServicePrincipalObjectId, readerAndDataAccessRoleId)
  scope: storage
  properties: {
    principalId: azureVirtualDesktopArmProviderServicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerAndDataAccessRoleId)
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createPrivateDnsZone) {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (createPrivateDnsZone) {
  parent: privateDnsZone
  name: '${storageAccountName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateEndpointVnetId
    }
  }
  tags: tags
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-09-01' = if (enableFilesPrivateEndpoint) {
  name: '${storageAccountName}-file-pe'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-file'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
  tags: tags
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-09-01' = if (attachPrivateDnsZoneGroup) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file'
        properties: {
          privateDnsZoneId: privateDnsZoneIdForGroup
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZone
  ]
}

output storageAccountName string = storage.name
output profilesShareName string = profilesShare.name
output appAttachShareName string = appAttachShare.name
output storageAccountId string = storage.id
