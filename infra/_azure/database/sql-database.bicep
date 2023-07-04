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

/*
** From: infra/_types/PrivateEndpointSettings.bicep
*/
@description('The settings for a private endpoint')
type PrivateEndpointSettings = {
  @description('The name of the private endpoint resource')
  name: string

  @description('The name of the resource group to hold the private endpoint')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to')
  subnetId: string
}

// ========================================================================
//     PARAMETERS
// ========================================================================

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
@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The name of the SQL server resource to use for provisioning the database')
param sqlServerName string

/*
** Settings
*/
@description('The number of DTUs to allocate to the database.')
param dtuCapacity int

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@allowed([ 'Basic', 'Standard', 'Premium' ])
@description('The tier or edition of the SKU')
param sku string = 'Standard'

@description('If true, enable availability zone redundancy')
param zoneRedundant bool = false

// ========================================================================
//     VARIABLES
// ========================================================================

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

// ========================================================================
//     AZURE RESOURCES
// ========================================================================

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
    requestedBackupStorageRedundancy: zoneRedundant ? 'Zone' : 'Local'
    readScale: sku == 'Premium' ? 'Enabled' : 'Disabled'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: zoneRedundant
  }
}

module privateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: 'private-endpoint-for-sqldb'
  scope: resourceGroup(privateEndpointSettings!.resourceGroupName)
  params: {
    name: privateEndpointSettings!.name
    location: location
    tags: tags

    // Dependencies
    linkServiceName: '${sqlServer.name}/${sqlDatabase.name}'
    linkServiceId: sqlServer.id
    subnetResourceId: privateEndpointSettings!.subnetId

    // Settings:
    dnsZoneName: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    groupIds: [ 'sqlServer' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: sqlDatabase
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

output id string = sqlDatabase.id
output name string = sqlDatabase.name
output connection_string string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Authentication=Active Directory Default'

output sql_server_id string = sqlServer.id
output sql_server_name string = sqlServer.name
