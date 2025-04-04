targetScope = 'resourceGroup'

// alle parameters/namen toevoegen
param location string = resourceGroup().location
param aciName string = 'aciscraenen03'
param vnetName string = 'vnetscraenen03'
param aciSubnetName string = 'subnetscraenen03'
param appGatewaySubnetName string = 'subnetscraenen032'
param appGatewayName string = 'appgatewaysc'
param publicIPName string = 'publicipsc'
//network.bicep module toeveogen
module network './modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    vnetName: vnetName
    location: location
    aciSubnetName: aciSubnetName
    appGatewaySubnetName: appGatewaySubnetName
  }
}

//aci.bicep module toeveogen
module aci './modules/aci.bicep' = {
  name: 'aciDeployment'
  dependsOn: [ network ]
  params: {
    name: aciName
    location: location
    vnetName: vnetName
    subnetName: aciSubnetName
    acrName: 'acrscraenen03'
  }
}
//appgateway.bicep module toeveogen
module appGateway './modules/appgateway.bicep' = {
  name: 'appGatewayDeployment'
  dependsOn: [ network ]
  params: {
    location: location
    vnetName: vnetName
    subnetName: appGatewaySubnetName
    appGatewayName: appGatewayName
    publicIPName: publicIPName
    aciPrivateIP: aci.outputs.privateIP
  }
}

output appGatewayPublicIP string = appGateway.outputs.publicIP
output aciPrivateIP string = aci.outputs.privateIP
