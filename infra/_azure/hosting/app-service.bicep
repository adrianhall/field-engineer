// ========================================================================
//     USER-DEFINED TYPES
// ========================================================================

/*
** From infra/_types/DiagnosticSettings.bicep
*/
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The audit log retention policy')
  auditLogRetentionInDays: int

  @description('The diagnostic log retention policy')
  diagnosticLogRetentionInDays: int

  @description('If true, enable audit logging')
  enableAuditLogs: bool

  @description('If true, enable diagnostic logging')
  enableDiagnosticLogs: bool
}

// ========================================================================
//     PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The name of the App Service Plan resource, for hosting')
param appServicePlanName string

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The name of the managed identity for this service')
param managedIdentityName string

@description('The ID of the outbound subnet to link, or blank if not provided')
param subnetResourceId string = ''

/*
** Service settings
*/
@description('The list of application settings for this app service')
param appSettings object

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('IP Security Restrictions to configure')
param ipSecurityRestrictions object[] = []

@description('The service prefix - used to tag the resource for azd deployment')
param servicePrefix string

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
    alwaysOn: true
    detailedErrorLoggingEnabled: diagnosticSettings.enableDiagnosticLogs
    httpLoggingEnabled: diagnosticSettings.enableDiagnosticLogs
    requestTracingEnabled: diagnosticSettings.enableDiagnosticLogs
    ftpsState: 'Disabled'
    ipSecurityRestrictions: ipSecurityRestrictions
    minTlsVersion: '1.2'
  }
}

var networkIsolationAppServiceProperties = !empty(subnetResourceId) ? {
  virtualNetworkSubnetId: subnetResourceId
  vnetRouteAllEnabled: true
} : {}

// ========================================================================
//     AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': servicePrefix })
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
    properties: appSettings
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
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

// ========================================================================
//     OUTPUTS
// ========================================================================

output id string = appService.id
output name string = appService.name

output hostname string = appService.properties.defaultHostName
output uri string = 'https://${appService.properties.defaultHostName}'
