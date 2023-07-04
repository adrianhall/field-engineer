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

@description('The name of the public IP address resource, if enablePublicIpAddress is true.')
param publicIpAddressName string = ''

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

@description('If true, create a public IP address for the bastion host.')
param enablePublicIpAddress bool = false

@allowed([ 'Basic', 'Standard' ])
@description('The pricing SKU to choose.')
param sku string = 'Basic'

@description('The ID of the subnet to link the bastion host to.')
param subnetId string

@description('If true, enable availability zone redundancy.')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var pipName = !empty(publicIpAddressName) ? publicIpAddressName : 'pip-${name}'

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'BastionAuditLogs'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [

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

module publicIpAddress '../networking/public-ip-address.bicep' = if (enablePublicIpAddress) {
  name: pipName
  params: {
    name: pipName
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    allocationMethod: 'Static'
    diagnosticSettings: diagnosticSettings
    domainNameLabel: name
    ipAddressType: 'IPv4'
    sku: 'Standard'
    tier: 'Regional'
    zoneRedundant: zoneRedundant
  }
}

resource createdResource 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    enableTunneling: sku == 'Standard' ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: enablePublicIpAddress ? publicIpAddress.outputs.id : null
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
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

output hostname string = publicIpAddress.outputs.hostname
