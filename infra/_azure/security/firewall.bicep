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
@description('The resource ID of the Firewall Policy that should be attached to this firewall.')
param firewallPolicyId string = ''

@description('The Resource ID for the Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@description('The list of application rule collections to configure')
param applicationRuleCollections object[] = []

@description('The diagnostic settings to use for this resource.')
param diagnosticSettings DiagnosticSettings

@description('The list of NAT rule collections to configure.')
param natRuleCollections object[] = []

@description('The list of network rule collections to configure.')
param networkRuleCollections object[] = []

@allowed([ 'Standard', 'Premium' ])
@description('The pricing SKU to use for this resource')
param sku string = 'Standard'

@description('The ID of the subnet to link the firewall to.')
param subnetId string

@allowed([ 'Alert', 'Deny', 'Off' ])
@description('The operational mode for Threat Intel')
param threatIntelMode string = 'Deny'

@description('True if you want the resource to be zone redundant')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var pipName = !empty(publicIpAddressName) ? publicIpAddressName : 'pip-${name}'

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'AZFWApplicationRuleAggregation'
  'AZFWNatRuleAggregation'
  'AZFWNetworkRuleAggregation'
  'AZFWThreatIntel'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'AZFWApplicationRule'
  'AZFWFlowTrace'
  'AZFWIdpsSignature'
  'AZFWNatRule'
  'AZFWNetworkRule'
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

module publicIpAddress '../networking/public-ip-address.bicep'= {
  name: pipName
  params: {
    diagnosticSettings: diagnosticSettings
    location: location
    name: pipName
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    allocationMethod: 'Static'
    domainNameLabel: name
    ipAddressType: 'IPv4'
    sku: 'Standard'
    tier: 'Regional'
    zoneRedundant: zoneRedundant
  }
}

resource createdResource 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    firewallPolicy: !empty(firewallPolicyId) ? { id: firewallPolicyId } : null
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpAddress.outputs.id
          }
        }
      }
    ]
    sku: {
      name: 'AZFW_VNet'
      tier: sku
    }
    applicationRuleCollections: applicationRuleCollections
    natRuleCollections: natRuleCollections
    networkRuleCollections: networkRuleCollections
    threatIntelMode: threatIntelMode
  }
  zones: zoneRedundant ? [ '1', '2', '3' ] : []
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
output internal_ip_address string = createdResource.properties.ipConfigurations[0].properties.privateIPAddress
