// acr resource toevoegen
resource acr 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: 'acrscraenen03'
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
// pull token toevoegen
resource token 'Microsoft.ContainerRegistry/registries/tokens@2024-11-01-preview' = {
  parent: acr
  name: 'pull-token'
  properties: {
    scopeMapId: resourceId('Microsoft.ContainerRegistry/registries/scopeMaps', acr.name, '_repositories_pull')
    status: 'enabled'
    
  }
}


