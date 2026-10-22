param location string
param keyVaultName string
@secure()
param localAdminUsername string
@secure()
param localAdminPassword string
param hostPoolIdentityPrincipalId string
param tags object
@description('Store the AD DS domain join account in Key Vault, for session hosts that join an Active Directory domain.')
param createDomainJoinSecrets bool = false
@secure()
param domainJoinUsername string = ''
@secure()
param domainJoinPassword string = ''

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

// Learn: an AD DS join needs one secret for the domain join account's username and one for its password, which
// the host pool's managed identity reads (Key Vault Secrets User, assigned below).
// https://learn.microsoft.com/azure/virtual-desktop/deploy-azure-virtual-desktop#prerequisites
resource domainJoinUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = if (createDomainJoinSecrets) {
  parent: vault
  name: 'sessionHostDomainJoinUsername'
  properties: {
    value: domainJoinUsername
  }
}

resource domainJoinPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2026-02-01' = if (createDomainJoinSecrets) {
  parent: vault
  name: 'sessionHostDomainJoinPassword'
  properties: {
    value: domainJoinPassword
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
output domainJoinUserSecretUri string = createDomainJoinSecrets ? domainJoinUsernameSecret!.properties.secretUri : ''
output domainJoinPwdSecretUri string = createDomainJoinSecrets ? domainJoinPasswordSecret!.properties.secretUri : ''
