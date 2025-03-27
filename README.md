# Assignment_2
repo for assignment 2 Cloud Platforms


**Author**: Sam Craenen  
**Date**: 30 maart 2025

## Introduction
This document provides a step-by-step guide on how to automate a basic CRUD application using Azure and Bicep (IaC). Key components
- ACR for the application image
- ACI to run the application
- App gateway to make it publicly available
- Azure monitor to monitor the application

## Diagram
We start with making our Diagram. This will give you a visual view on what you need to make later on.


## Installation
**Azure CLI**: for windows, start by going to this website: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?pivots=msi and click on either the 32bit or 64bit download button.

**Bicep**: After you installed the Azure CLI, you need to install bicep. My recommendation for this is to use visual studio code for your project.
This way you can just install the bicep extension.

## File structure
.
└── Project folder/
    ├── README.MD
    ├── example-flask-crud/
    │   ├── Dockerfile
    │   └── <other application files>
    ├── modules/
    │   ├── acr.bicep
    │   ├── network.bicep
    │   ├── aci.bicep
    │   └── appgateway.bicep
    └── main.bicep

## Resource Group
Start by making a standard Resource group.
You can do this by running the following command in your terminal.

az group create --name MyResourceGroup --location westeurope


## ACR (Azure Container Registry)
After you've made the resource group, we're going to continue with our ACR.

This is the acr.bicep file we're going to use:

resource acr 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: 'acrscraenen03'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true // this enables us to push the image later on
  }
}
resource token 'Microsoft.ContainerRegistry/registries/tokens@2024-11-01-preview' = {
  parent: acr
  name: 'pull-token'
  properties: {
    scopeMapId: resourceId('Microsoft.ContainerRegistry/registries/scopeMaps', acr.name, '_repositories_pull')
    status: 'enabled'
    
  }
}

# ACR deploy
To deploy your ACR, run the following command

az deployment group create --resource-group MyResourceGroup --template-file acr.bicep --mode Incremental


after this, were going to push the image to the ACR:
# Login to ACR (requires Docker)
az acr login --name acrscraenen03

# Build the image (go into the Dockerfile folder)
docker build -t acrscraenen03.azurecr.io/mycrudapp:latest .

# Push to ACR
docker push acrscraenen03.azurecr.io/mycrudapp:latest

## VNet and Subnets
After the ACR deploy, we're going to focus on setting up our virtual network and it's subnets.

this is the network.bicep file you need for this.

param vnetName string
param location string
param aciSubnetName string
param appGatewaySubnetName string
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
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


the reason we have 2 subnets is because of the application gateway later on. 
so we have:
- 1 subnet for the ACI 
- 1 subnet for the application gateway

# Verification
You can run the following command to verify that you're deployment was successful.

az network vnet subnet list --resource-group MyResourceGroup --vnet-name vnetscraenen03 --output table                 

## ACI (Azure Container Instance)
Next up is the container instance.

This is the code in my aci.bicep file:

param name string
param location string
param vnetName string
param subnetName string
param acrName 'acrscraenen03'
resource aci 'Microsoft.ContainerInstance/containerGroups@2024-11-01-preview' = {
  name: name
  location: location
  properties: {
    subnetIds: [
      {
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
      }
    ]
    containers: [
      {
        name: 'crud-container'
        properties: {
          image: '${acrName}.azurecr.io/mycrudapp:latest'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Private'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
      
    }
    imageRegistryCredentials: [
      {
        server: '${acrName}.azurecr.io'
        username: 'acrToken'
        password: 'zjV+dCMvLoF9vSHiPpu+/SltdnZz138JZA7LjfHY8a+ACRBgqKiP'
      }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: '1ffe2e20-0051-4222-ad1d-4d7a14e8bd69'
        workspaceKey: 'yJmX7ms4W4fxQUP8CLq7mFtVwI1vTwV6dkQcrr3R3RAA2r30htYK0yWR6Q3/smXmJpw6CHy1t6V4z09QFxf2zQ=='
        logType: 'ContainerInsights'
      }
    }
  }
}


output privateIP string = aci.properties.ipAddress.ip


# Verification
You can run the following command to verify that you're deployment was successful.

az container show --name aciscraenen03 --resource-group MyResourceGroup --query "ipAddress.ip"                            

This should return the private IP of your ACI.

## Application Gateway
Lastly is the application gateway.
This will make sure that our application is publicly available.

this is our appgateway.bicep file:

param location string
param vnetName string
param subnetName string
param aciPrivateIP string
param appGatewayName string
param publicIPName string




resource publicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}
resource appGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2  // ← Critical fix
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: { id: publicIP.id }
        }
      }
    ]
    frontendPorts: [{ name: 'frontendPort', properties: { port: 80 } }]
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {
          backendAddresses: [{ ipAddress: aciPrivateIP }]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'frontendPort')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          priority: 1001
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'backendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'httpSettings')
          }
        }
      }
    ]
  }
}

output publicIP string = publicIP.properties.ipAddress


# Verification
You can run the following command to verify that you're deployment was successful.

az network public-ip show --resource-group MyResourceGroup --name publicipsc --query "ipAddress" --output tsv

This will give you the public IP back.
This is also the IP that you will enter in your browser.

Which is also the second way to verify that the deployment was successful.


## main.bicep
This is the core file of the deployment. This is where everything get's connected.

This is the content of the main.bicep file:

targetScope = 'resourceGroup'
param location string = resourceGroup().location
param aciName string = 'aciscraenen03'
param vnetName string = 'vnetscraenen03'
param aciSubnetName string = 'subnetscraenen03'
param appGatewaySubnetName string = 'subnetscraenen032'
param appGatewayName string = 'appgatewaysc'
param publicIPName string = 'publicipsc'
module network './modules/network.bicep' = {
  name: 'networkDeployment'
  params: {
    vnetName: vnetName
    location: location
    aciSubnetName: aciSubnetName
    appGatewaySubnetName: appGatewaySubnetName
  }
}


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

## Deploy
to succesfully deploy the whole application, you need to run the following command

az deployment group create --resource-group MyResourceGroup --template-file main.bicep --mode Incremental

This will deploy everything. it can take a while. then you can find the public ip, with the same command i showed you earlier.

# ACR vs The rest

There is a reason i only provided the deploy commands for the ACR and the main.bicep files.
It's because it would be really complicated to integrate the automation of the ACR deployment + Image push, combined with the rest.

So that's why i manually deploy the ACR first / alone. And then deploy the rest.

## Conclusion

If you've followed all the steps, you should now have a running application.