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

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic logging settings')
param diagnosticSettings DiagnosticSettings

@description('The location of the resource')
param location string = resourceGroup().location

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The name of the SQL server resource')
param sqlServerName string

/*
** Service settings
*/
@description('The number of DTUs to allocate to the database.')
param dtuCapacity int

@description('If true, enable availability zone redundancy')
param enableZoneRedundancy bool = false

@allowed([ 'Basic', 'Standard', 'Premium' ])
@description('The pricing SKU to use')
param sku string = 'Standard'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'SQLSecurityAuditEvents'
  'DevOpsOperationsAudit'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'AutomaticTuning'
  'Blocks'
  'DatabaseWaitStatistics'
  'Deadlocks'
  'Errors'
  'QueryStoreRuntimeStatistics'
  'QueryStoreWaitStatistics'
  'SQLInsights'
  'Timeouts'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: name
  parent: sqlServer
  location: location
  tags: union(tags, { displayName: name })
  sku: {
    name: sku
    tier: sku
    capacity: dtuCapacity
  }
  properties: {
    requestedBackupStorageRedundancy: enableZoneRedundancy ? 'Zone' : 'Local'
    readScale: sku == 'Premium' ? 'Enabled' : 'Disabled'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: enableZoneRedundancy
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: sqlDatabase
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

output id string = sqlDatabase.id
output name string = sqlDatabase.name

output connection_string string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Authentication=Active Directory Default'
