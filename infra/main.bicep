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

@description('Node.js runtime version')
param nodeVersion string = '20-lts'

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
// Log Analytics Workspace
// ---------------------------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// Application Insights
// ---------------------------------------------------------------------------
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${abbrs.insightsComponents}${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
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
      linuxFxVersion: 'NODE|${nodeVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: appServiceSku != 'F1'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Disable App Service built-in authentication (Easy Auth)
// ---------------------------------------------------------------------------
resource webAppAuth 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: webApp
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: false
    }
    globalValidation: {
      unauthenticatedClientAction: 'AllowAnonymous'
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs – consumed by azd for deployment
// ---------------------------------------------------------------------------
output AZURE_LOCATION string = location
output WEB_URI string = 'https://${webApp.properties.defaultHostName}'
output WEB_APP_NAME string = webApp.name
output APPINSIGHTS_NAME string = appInsights.name
output APPINSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.name
