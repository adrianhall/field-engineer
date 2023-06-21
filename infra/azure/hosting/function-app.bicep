// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type DiagnosticSettings = {
  @description('The name of the Log Analytics Workspace')
  logAnalyticsWorkspaceName: string

  @description('The audit log retention policy')
  auditLogRetentionInDays: int

  @description('The diagnostic log retention policy')
  diagnosticLogRetentionInDays: int

  @description('If true, enable audit logging')
  enableAuditLogs: bool

  @description('If true, enable diagnostic logging')
  enableDiagnosticLogs: bool
}

type NetworkIsolationSettings = {
  @description('If set, the name of the inbound private endpoint')
  privateEndpointSubnetName: string?

  @description('If set, the name of the subnet for service connections')
  serviceConnectionSubnetName: string?

  @description('If set, the name of the virtual network to use')
  virtualNetworkName: string?
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The network isolation settings')
param networkIsolationSettings NetworkIsolationSettings = {}

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The name of the App Service Plan resource, for hosting')
param appServicePlanName string

@description('The name of the managed identity for this service')
param managedIdentityName string

@description('The name of the storage account for this service')
param storageAccountName string

/*
** Service settings
*/
@description('The list of application settings for this app service')
param appSettings object

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@allowed([ 'node', 'dotnet', 'java' ])
@description('The language worker runtime to load in the function app.')
param runtime string = 'node'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'AppServiceAntivirusScanAuditLogs'
  'AppServiceAuditLogs'
  'AppServiceFileAuditLogs'
  'AppServiceIPSecAuditLogs'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'AppServiceAppLogs'
  'AppServiceConsoleLogs'
  'AppServiceHTTPLogs'
  'AppServicePlatformLogs'
  'FunctionAppLogs'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

var defaultAppServiceProperties = {
  clientAffinityEnabled: false
  httpsOnly: true
  publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  serverFarmId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
  siteConfig: {
    detailedErrorLoggingEnabled: diagnosticSettings.enableDiagnosticLogs
    httpLoggingEnabled: diagnosticSettings.enableDiagnosticLogs
    requestTracingEnabled: diagnosticSettings.enableDiagnosticLogs
    ftpsState: 'Disabled'
    minTlsVersion: '1.2'
  }
}

var networkIsolationAppServiceProperties = contains(networkIsolationSettings, 'serviceConnectionSubnetName') ? {
  virtualNetworkSubnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', networkIsolationSettings.virtualNetworkName ?? '', networkIsolationSettings.serviceConnectionSubnetName ?? '')
} : {}

var defaultAppSettings = {
  // Functions Runtime
  WEBSITE_CONTENTSHARE: toLower(name)
  FUNCTIONS_EXTENSION_VERSION: '~4'
  WEBSITE_NODE_DEFAULT_VERSION: '~16'
  FUNCTIONS_WORKER_RUNTIME: runtime

  // Application Insights
  ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
  XDT_MicrosoftApplicationInsights_Mode: 'recommended'
  InstrumentationEngine_EXTENSION_VERSION: '~1'
  XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: union(defaultAppServiceProperties, networkIsolationAppServiceProperties)

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(defaultAppSettings, appSettings, {
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
      WEBSITE_RUN_FROM_PACKAGE: '1'
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
    })
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: { level: 'Verbose' }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 2
          retentionInMb: 100
        }
      }
    }
    dependsOn: [
      configAppSettings
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: functionApp
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', diagnosticSettings.logAnalyticsWorkspaceName)
    logs: logSettings
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true }
      }
    ]
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = functionApp.id
output name string = functionApp.name

output hostname string = functionApp.properties.defaultHostName
output uri string = 'https://${functionApp.properties.defaultHostName}'
