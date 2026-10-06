targetScope = 'subscription'

param hostPoolManagedIdentityPrincipalId string
param azureVirtualDesktopServicePrincipalObjectId string = ''
param assignAutoscaleRolesToHostPoolIdentity bool = true
param assignAutoscaleRolesToAvdServicePrincipal bool = false
param powerOnOffContributorRoleDefinitionId string
param virtualMachineContributorRoleDefinitionId string

resource managedIdentityPowerOnOffAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignAutoscaleRolesToHostPoolIdentity) {
  name: guid(subscription().id, hostPoolManagedIdentityPrincipalId, powerOnOffContributorRoleDefinitionId)
  properties: {
    principalId: hostPoolManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', powerOnOffContributorRoleDefinitionId)
  }
}

resource managedIdentityVirtualMachineContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignAutoscaleRolesToHostPoolIdentity) {
  name: guid(subscription().id, hostPoolManagedIdentityPrincipalId, virtualMachineContributorRoleDefinitionId)
  properties: {
    principalId: hostPoolManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineContributorRoleDefinitionId)
  }
}

resource avdServicePrincipalPowerOnOffAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignAutoscaleRolesToAvdServicePrincipal && !empty(azureVirtualDesktopServicePrincipalObjectId)) {
  name: guid(subscription().id, azureVirtualDesktopServicePrincipalObjectId, powerOnOffContributorRoleDefinitionId)
  properties: {
    principalId: azureVirtualDesktopServicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', powerOnOffContributorRoleDefinitionId)
  }
}

resource avdServicePrincipalVirtualMachineContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignAutoscaleRolesToAvdServicePrincipal && !empty(azureVirtualDesktopServicePrincipalObjectId)) {
  name: guid(subscription().id, azureVirtualDesktopServicePrincipalObjectId, virtualMachineContributorRoleDefinitionId)
  properties: {
    principalId: azureVirtualDesktopServicePrincipalObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', virtualMachineContributorRoleDefinitionId)
  }
}
