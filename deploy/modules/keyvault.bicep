param location string
param keyVaultName string
@secure()
param localAdminUsername string
@secure()
param localAdminPassword string
param hostPoolIdentityPrincipalId string
param tags object

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource vault 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
  tags: tags
}

resource usernameSecret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = {
  parent: vault
  name: 'sessionHostLocalAdminUsername'
  properties: {
    value: localAdminUsername
  }
}

resource passwordSecret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = {
  parent: vault
  name: 'sessionHostLocalAdminPassword'
  properties: {
    value: localAdminPassword
  }
}

resource identitySecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, hostPoolIdentityPrincipalId, keyVaultSecretsUserRoleId)
  scope: vault
  properties: {
    principalId: hostPoolIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

output localAdminUsernameSecretUri string = usernameSecret.properties.secretUri
output localAdminPwdSecretUri string = passwordSecret.properties.secretUri
output keyVaultName string = vault.name
