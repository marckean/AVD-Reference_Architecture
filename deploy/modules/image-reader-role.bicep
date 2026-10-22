targetScope = 'resourceGroup'

// Lets the host pool managed identity read a custom gallery image that lives in another resource group. The
// identity creates the session hosts, and the Desktop Virtualization Virtual Machine Contributor role it holds on its
// own resource group includes the gallery reads (Microsoft.Compute/galleries/read, galleries/images/read and
// galleries/images/versions/read). Reader on the gallery's resource group covers the same reads there.
// https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/compute#desktop-virtualization-virtual-machine-contributor

@description('Principal ID of the host pool managed identity.')
param principalId string

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource imageReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, readerRoleId)
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
  }
}
