targetScope = 'resourceGroup'

// Lets the host pool managed identity join an existing subnet that lives in another resource group,
// without a subscription-wide role. Desktop Virtualization Virtual Machine Contributor includes
// Microsoft.Network/virtualNetworks/subnets/join/action; scoping it to the subnet keeps it narrow.
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
