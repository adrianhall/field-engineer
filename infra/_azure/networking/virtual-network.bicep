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
@description('If a DDoS Protection Plan is in use, the ID of the plan to associate with this virtual network')
param ddosProtectionPlanId string = ''

@description('The Resource ID for the Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@description('The CIDR block to use for the address space of this virtual network.')
param addressSpace string

@description('The diagnostic settings to use for this resource.')
param diagnosticSettings DiagnosticSettings

@description('The list of subnets to pre-create within the virtual network.')
param subnets object[]

// ========================================================================
// PARAMETERS
// ========================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'VMProtectionAlerts'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource createdResource 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    ddosProtectionPlan: !empty(ddosProtectionPlanId) ? {
      id: ddosProtectionPlanId
    } : null
    enableDdosProtection: !empty(ddosProtectionPlanId)
    subnets: subnets
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: createdResource
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

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = createdResource.id
output name string = createdResource.name
output subnets object[] = createdResource.properties.subnets
