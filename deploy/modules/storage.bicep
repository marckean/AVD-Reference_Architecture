param location string
param storageAccountName string
param pilotUsersGroupObjectId string
param azureVirtualDesktopServicePrincipalObjectId string
param azureVirtualDesktopArmProviderServicePrincipalObjectId string
param enableFilesPrivateEndpoint bool
param privateEndpointSubnetId string
param tags object

var storageFileDataSmbShareContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var readerAndDataAccessRoleId = 'c12c1c16-33a1-487b-954d-41c89c60f349'
var profilesShareName = 'profiles'
var appAttachShareName = 'appattach'
var privateEndpointVnetId = split(privateEndpointSubnetId, '/subnets/')[0]

resource storage 'Microsoft.Storage/storageAccounts@2026-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
      defaultSharePermission: 'None'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: enableFilesPrivateEndpoint ? 'Deny' : 'Allow'
    }
  }
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
    principalType: 'Group'
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

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (enableFilesPrivateEndpoint) {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (enableFilesPrivateEndpoint) {
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

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-09-01' = if (enableFilesPrivateEndpoint) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output storageAccountName string = storage.name
output profilesShareName string = profilesShare.name
output appAttachShareName string = appAttachShare.name
output storageAccountId string = storage.id
