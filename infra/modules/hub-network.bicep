targetScope = 'subscription'

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

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

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

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for this deployment.')
param diagnosticSettings DiagnosticSettings?

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the jump host.')
param administratorPassword string = newGuid()

@minLength(8)
@description('The username for the administrator account on the jump host.')
param administratorUsername string = 'adminuser'

@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string = '10.0.0.0/20'

@description('If enabled, a Bastion Host will be deployed with a public IP address.')
param enableBastionHost bool = false

@description('If enabled, DDoS Protection will be enabled on the virtual network')
param enableDDoSProtection bool = true

@description('If enabled, an Azure Firewall will be deployed with a public IP address.')
param enableFirewall bool = true

@description('If enabled, a Windows 11 jump host will be deployed.  Ensure you enable the bastion host as well.')
param enableJumpHost bool = false

@description('If enabled, a Key Vault will be deployed in the resource group.')
param enableKeyVault bool = false

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

// Budget amounts
//  All values are calculated in dollars (rounded to nearest dollar) in the South Central US region.
var budgetCategories = deploymentSettings.isProduction ? {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 87              /* Estimate 1GiB/day Analytics, 1GiB/day Basic Logs  */
  applicationInsights: 152      /* Estimate 5GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Basic plan, 100GiB processed */
  bastionHost: 212              /* Standard plan */
  jumphost: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
} : {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 69              /* Estimate 1GiB/day Analytics + Basic Logs  */
  applicationInsights: 187      /* Estimate 1GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Standard plan, 100GiB processed */
  bastionHost: 139              /* Basic plan */
  jumphost: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
}
var budgetAmount = reduce(map(items(budgetCategories), (obj) => obj.value), 0, (total, amount) => total + amount)

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.hubResourceGroup
}

module ddosProtectionPlan '../core/network/ddos-protection-plan.bicep' = if (enableDDoSProtection) {
  name: 'hub-ddos-protection-plan'
  scope: resourceGroup
  params: {
    name: resourceNames.hubDDoSProtectionPlan
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module logAnalytics '../core/monitor/log-analytics-workspace.bicep' = if (enableLogAnalytics) {
  name: 'hub-log-analytics'
  scope: resourceGroup
  params: {
    name: resourceNames.logAnalyticsWorkspace
    location: deploymentSettings.location
    tags: moduleTags

    // Settings
    sku: 'PerGB2018'
  }
}

module applicationInsights '../core/monitor/application-insights.bicep' = if (enableApplicationInsights && enableLogAnalytics) {
  name: 'hub-application-insights'
  scope: resourceGroup
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

module keyVault '../core/security/key-vault.bicep' = if (enableJumpHost || enableKeyVault) {
  name: 'hub-key-vault'
  scope: resourceGroup
  params: {
    name: resourceNames.hubKeyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''

    // Settings
    diagnosticSettings: diagnosticSettings
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
    ]
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: 'hub-virtual-network'
  scope: resourceGroup
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
  scope: resourceGroup
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

module routeTable '../core/network/route-table.bicep' = if (enableFirewall) {
  name: 'hub-route-table'
  scope: resourceGroup
  params: {
    name: resourceNames.hubRouteTable
    location: deploymentSettings.location
    tags: moduleTags

    // Settings
    routes: [
      {
        name: 'defaultEgress'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: firewall.outputs.internal_ip_address
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module bastionHost '../core/network/bastion-host.bicep' = if (enableBastionHost) {
  name: 'hub-bastion-host'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBastionHost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetBastionHost].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubBastionPublicIpAddress
    sku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module jumphost '../core/compute/windows-jumphost.bicep' = if (enableJumpHost) {
  name: 'hub-jumphost'
  scope: resourceGroup
  params: {
    name: resourceNames.hubJumphost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: enableLogAnalytics ? logAnalytics.outputs.id : ''
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetJumphost].id

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    diagnosticSettings: diagnosticSettings
    
  }
}

module writeJumpHostCredentials '../core/security/key-vault-secrets.bicep' = if (enableJumpHost) {
  name: 'hub-write-jumphost-credentials'
  scope: resourceGroup
  params: {
    name: keyVault.outputs.name
    secrets: [
      { key: 'Jumphost--AdministratorPassword', value: administratorPassword          }
      { key: 'Jumphost--AdministratorUsername', value: administratorUsername          }
      { key: 'Jumphost--ComputerName',          value: jumphost.outputs.computer_name }
    ]
  }
}

module hubBudget '../core/cost-management/budget.bicep' = {
  name: 'hub-budget'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBudget
    amount: budgetAmount
    contactEmails: [
      deploymentSettings.tags['azd-owner-email']
    ]
    resourceGroups: [
      resourceGroup.name
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output application_insights_id string = applicationInsights.outputs.id
output bastion_hostname string = enableBastionHost ? bastionHost.outputs.hostname : ''
output firewall_hostname string = enableFirewall ? firewall.outputs.hostname : ''
output firewall_ip_address string = enableFirewall ? firewall.outputs.internal_ip_address : ''
output jumphost_computer_name string = enableJumpHost ? jumphost.outputs.computer_name : ''
output key_vault_id string = enableJumpHost || enableKeyVault ? keyVault.outputs.id : ''
output route_table_id string = enableFirewall ? routeTable.outputs.id : ''
output virtual_network_id string = virtualNetwork.outputs.id
output workspace_id string = enableLogAnalytics ? logAnalytics.outputs.id : ''
