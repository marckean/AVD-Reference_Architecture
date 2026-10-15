targetScope = 'resourceGroup'

// Lets the host pool managed identity use an existing subnet that lives in another resource group,
// without a subscription-wide role:
// - Desktop Virtualization Virtual Machine Contributor on the subnet only, for subnets/join/action.
// - Reader on the network resource group, because the session host configuration's network check reads
//   the virtual network itself (the subnet's parent), which a subnet-scoped role doesn't cover. Found in
//   live testing: AuthorizationFailed on Microsoft.Network/virtualNetworks/read, fault context
//   NetworkResourcesValidRule.
// https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/compute#desktop-virtualization-virtual-machine-contributor

@description('Name of the virtual network that holds the session host subnet.')
param vnetName string

@description('Name of the session host subnet.')
param subnetName string

@description('Principal ID of the host pool managed identity.')
param principalId string

@description('Role definition ID to assign on the subnet.')
param roleDefinitionId string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: subnetName
}

resource subnetJoin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subnet.id, principalId, roleDefinitionId)
  scope: subnet
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource networkReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, readerRoleId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
  }
}
