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
@allowed([ 'Dynamic', 'Static' ])
@description('The public IP address allocation method.  The default is dynamic allocation.')
param allocationMethod string = 'Dynamic'

@description('The diagnostic settings to use for this resource.')
param diagnosticSettings DiagnosticSettings

@description('The DNS label for the resource.  This will become a domain name of domainlabel.region.cloudapp.azure.com')
param domainNameLabel string

@allowed([ 'IPv4', 'IPv6'])
@description('The type of public IP address to generate')
param ipAddressType string = 'IPv4'

@allowed([ 'Basic', 'Standard' ])
param sku string = 'Basic'

@allowed([ 'Regional', 'Global' ])
param tier string = 'Regional'

@description('True if you want the resource to be zone redundant')
param zoneRedundant bool = false

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [

] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'DDoSMitigationFlowLogs'
  'DDoSMitigationReports'
  'DDoSProtectionNotifications'
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

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
    publicIPAddressVersion: ipAddressType
    publicIPAllocationMethod: allocationMethod
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: sku
    tier: tier
  }
  zones: zoneRedundant ? [ '1', '2', '3' ] : []
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: publicIpAddress
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

output id string = publicIpAddress.id
output name string = publicIpAddress.name

output hostname string = publicIpAddress.properties.dnsSettings.fqdn
