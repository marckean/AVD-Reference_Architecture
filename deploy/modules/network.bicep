param location string
param workloadPrefix string
param vnetAddressPrefix string
param sessionHostSubnetPrefix string
param tags object

resource publicIp 'Microsoft.Network/publicIPAddresses@2025-09-01' = {
  name: '${workloadPrefix}-nat-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

resource natGateway 'Microsoft.Network/natGateways@2025-09-01' = {
  name: '${workloadPrefix}-nat'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
  }
  tags: tags
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-09-01' = {
  name: '${workloadPrefix}-sh-nsg'
  location: location
  tags: tags
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-09-01' = {
  name: '${workloadPrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-session-hosts'
        properties: {
          addressPrefix: sessionHostSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: natGateway.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  tags: tags
}

output sessionHostSubnetId string = vnet.properties.subnets[0].id
output vnetId string = vnet.id
