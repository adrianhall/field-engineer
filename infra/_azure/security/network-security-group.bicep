// ========================================================================
// USER-DEFINED TYPES
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
// PARAMETERS
// ========================================================================

@description('The Azure region to deploy this resource into.')
param location string

@description('The name of the main resource to deploy.')
param name string

@description('The tags to associate with the resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The Resource ID for the Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@description('The diagnostic settings to use for this resource.')
param diagnosticSettings DiagnosticSettings

@description('The list of security rules to install in the NSG.')
param securityRules object[]

// ========================================================================
// VARIABLES
// ========================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [

] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'NetworkSecurityGroupEvent'
  'NetworkSecurityGroupRuleCounter'
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

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: nsg
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: logSettings
    metrics: []
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output id string = nsg.id
output name string = nsg.name
