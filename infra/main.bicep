targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters – azd supplies these automatically from environment config
// ---------------------------------------------------------------------------
@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g. dev, staging, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('App Service SKU (default: B1)')
param appServiceSku string = 'B1'

@description('PHP runtime version')
param phpVersion string = '8.4'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(resourceGroup().id, environmentName, location))
var appName = '${abbrs.webSitesAppService}${environmentName}-${resourceToken}'
var planName = '${abbrs.webServerFarms}${environmentName}-${resourceToken}'
var tags = {
  'azd-env-name': environmentName
}

// ---------------------------------------------------------------------------
// App Service Plan
// ---------------------------------------------------------------------------
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: appServiceSku
  }
  properties: {
    reserved: true // Linux
  }
}

// ---------------------------------------------------------------------------
// App Service (PHP on Linux)
// ---------------------------------------------------------------------------
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: union(tags, {
    'azd-service-name': 'web'
  })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PHP|${phpVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: appServiceSku != 'F1'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs – consumed by azd for deployment
// ---------------------------------------------------------------------------
output AZURE_LOCATION string = location
output WEB_URI string = 'https://${webApp.properties.defaultHostName}'
output WEB_APP_NAME string = webApp.name
