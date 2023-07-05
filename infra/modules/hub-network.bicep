targetScope = 'resourceGroup'

/*
** Hub Network Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network consists of a virtual network that hosts resources that
** are generally associated with a hub.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('The primary Azure region to host resources')
  location: string

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for this deployment.')
param diagnosticSettings DiagnosticSettings?

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Settings
*/
@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string

@description('If enabled, an App Gateway will be deployed with a public IP address.')
param enableAppGateway bool = false

@description('If enabled, a Bastion Host will be deployed with a public IP address.')
param enableBastionHost bool = false

@description('If enabled, DDoS Protection will be enabled on the virtual network')
param enableDDoSProtection bool = true

@description('If enabled, an Azure Firewall will be deployed with a public IP address.')
param enableFirewall bool = true

@description('If enabled, a Windows 11 jump host will be deployed.  Ensure you enable the bastion host as well.')
param enableJumpHost bool = false

@description('If enabled, a Log Analytics Workspace will be deployed in the resource group.')
param enableLogAnalytics bool = true

@description('If enabled, an Application Insights instance will be deployed in the resource group.')
param enableApplicationInsights bool = false

@description('The address spaces allowed to connect through the firewall.  By default, we allow all RFC1918 address spaces')
param internalAddressSpace string[] = [ '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' ]

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: 'NetworkHub'
  OpsCommitment: 'Platform operations'
})

// The subnet prefixes for the individual subnets inside the virtual network
var subnetPrefixes = [ for i in range(0, 16): cidrSubnet(addressPrefix, 26, i)]

// The individual subnet definitions.
var appGatewaySubnetDefinition = {
  name: resourceNames.hubSubnetBastionHost
  properties: {
    addressPrefix: subnetPrefixes[2]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var bastionHostSubnetDefinition = {
  name: resourceNames.hubSubnetBastionHost
  properties: {
    addressPrefix: subnetPrefixes[1]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var firewallSubnetDefinition = {
  name: resourceNames.hubSubnetFirewall
  properties: {
    addressPrefix: subnetPrefixes[0]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var jumphostSubnetDefinition = {
  name: resourceNames.hubSubnetJumphost
  properties: {
    addressPrefix: subnetPrefixes[3]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var subnets = union(
  enableAppGateway ? [appGatewaySubnetDefinition] : [],
  enableBastionHost ? [bastionHostSubnetDefinition] : [],
  enableFirewall ? [firewallSubnetDefinition] : [],
  enableJumpHost ? [jumphostSubnetDefinition] : []
)

// Some helpers for the firewall rules
var allowTraffic = { type: 'allow' }
var httpProtocol  = { port: '80', protocolType: 'HTTP' }
var httpsProtocol = { port: '443', protocolType: 'HTTPS' }
var azureFqdns = loadJsonContent('./azure-fqdns.jsonc')

// The firewall application rules
var applicationRuleCollections = [
  {
    name: 'Azure-Monitor'
    properties: {
      action: allowTraffic
      priority: 201
      rules: [
        {
          name: 'allow-azure-monitor'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.azureMonitor
        }
      ]
    }
  }
  {
    name: 'Core-Dependencies'
    properties: {
      action: allowTraffic
      priority: 200
      rules: [
        {
          name: 'allow-core-apis'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.coreServices
        }
        {
          name: 'allow-developer-services'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.developerServices
        }
        {
          name: 'allow-certificate-dependencies'
          protocols: [ httpProtocol, httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.certificateServices
        }
      ]
    }
  }
]

// Our firewall does not use network or NAT rule collections, but you can
// set them up here.
var networkRuleCollections = []
var natRuleCollections = []

// ========================================================================
// AZURE MODULES
// ========================================================================

module ddosProtectionPlan '../core/network/ddos-protection-plan.bicep' = if (enableDDoSProtection) {
  name: 'hub-ddos-protection-plan'
  params: {
    name: resourceNames.hubDDoSProtectionPlan
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module logAnalytics '../core/monitor/log-analytics-workspace.bicep' = if (enableLogAnalytics) {
  name: 'hub-log-analytics'
  params: {
    name: resourceNames.logAnalytics
    location: deploymentSettings.location
    tags: moduleTags

    // Settings
    sku: 'PerGB2018'
  }
}

module applicationInsights '../core/monitor/application-insights.bicep' = if (enableApplicationInsights && enableLogAnalytics) {
  name: 'hub-application-insights'
  params: {
    name: resourceNames.applicationInsights
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''

    // Settings
    kind: 'web'
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: 'hub-virtual-network'
  params: {
    name: resourceNames.hubVirtualNetwork
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    ddosProtectionPlanId: enableDDoSProtection ? ddosProtectionPlan.outputs.id : ''
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''

    // Settings
    addressPrefix: addressPrefix
    diagnosticSettings: diagnosticSettings
    subnets: subnets
  }
}

module firewall '../core/network/firewall.bicep' = if (enableFirewall) {
  name: 'hub-firewall'
  params: {
    name: resourceNames.hubFirewall
    location: deploymentSettings.location
    tags: moduleTags
    
    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetFirewall].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubFirewallPublicIpAddress
    sku: 'Standard'
    threatIntelMode: 'Deny'
    zoneRedundant: deploymentSettings.isProduction

    // Firewall rules
    applicationRuleCollections: applicationRuleCollections
    natRuleCollections: natRuleCollections
    networkRuleCollections: networkRuleCollections
  }
}

module bastionHost '../core/network/bastion-host.bicep' = if (enableBastionHost) {
  name: 'hub-bastion-host'
  params: {
    name: resourceNames.hubBastionHost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetBastionHost].id

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicIpAddress: deploymentSettings.isProduction
    publicIpAddressName: resourceNames.hubBastionPublicIpAddress
    sku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    zoneRedundant: deploymentSettings.isProduction
  }
}

// TODO: App Gateway

// TODO: Jump Host (from Landing Zone Accelerator)

// ========================================================================
// OUTPUTS
// ========================================================================

output application_insights_id string = applicationInsights.outputs.id
output bastion_hostname string = enableBastionHost ? bastionHost.outputs.hostname : ''
output firewall_hostname string = enableFirewall ? firewall.outputs.hostname : ''
output firewall_ip_address string = enableFirewall ? firewall.outputs.internal_ip_address : ''
output virtual_network_id string = virtualNetwork.outputs.id
output workspace_id string = enableLogAnalytics ? logAnalytics.outputs.id : ''
