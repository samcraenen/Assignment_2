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


