param location string
param workspaceName string
param tags object

resource workspace 'Microsoft.OperationalInsights/workspaces@2026-03-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: tags
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
