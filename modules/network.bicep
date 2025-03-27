// parameters overnemen van main.bicep
param vnetName string
param location string
param aciSubnetName string
param appGatewaySubnetName string
// virtual network resource toevoegen
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    // 2 subnets, een voor de aci en een voor de app gateway
    subnets: [
      {
        name: aciSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
              name: 'aciDelegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}
// network security group resource toevoegen
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'aci-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-http-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '10.0.0.4' 
        }
      }
    ]
  }
}




output vnetId string = vnet.id


