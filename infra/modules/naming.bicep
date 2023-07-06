targetScope = 'subscription'

/*
** Resource Naming
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Provides a name for every resource that may be created.
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

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The overrides for the naming scheme.  Load this from the naming.overrides.jsonc file.')
param overrides object = {}

// ========================================================================
// VARIABLES
// ========================================================================

// A unique token that is used as a differentiator for all resources.  All resources within the
// same deployment will have the same token.
var resourceToken = uniqueString(subscription().id, deploymentSettings.name, deploymentSettings.stage, deploymentSettings.location)

// The prefix for resource groups
var resourceGroupPrefix = 'rg-${deploymentSettings.name}-${deploymentSettings.stage}-${deploymentSettings.location}'

// The list of resource names that are used in the deployment.  The default
// names use Cloud Adoption Framework abbreviations.
// See: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
var defaultResourceNames = {
  // Hub network resources
  hubBastionHost: 'bas-${resourceToken}'
  hubBastionPublicIpAddress: 'pip-bas-${resourceToken}'
  hubBudget: 'budget-hub-${resourceToken}'
  hubDDoSProtectionPlan: 'ddos-${resourceToken}'
  hubFirewall: 'afw-${resourceToken}'
  hubFirewallPublicIpAddress: 'pip-afw-${resourceToken}'
  hubJumphost: 'vm-jump-${resourceToken}'
  hubKeyVault: 'kv-hub-${resourceToken}'
  hubResourceGroup: '${resourceGroupPrefix}-hub'
  hubRouteTable: 'rt-${resourceToken}'
  hubSubnetBastionHost: 'AzureBastionSubnet'
  hubSubnetFirewall: 'AzureFirewallSubnet'
  hubSubnetJumphost: 'JumphostSubnet'
  hubVirtualNetwork: 'vnet-hub-${resourceToken}'

  // Common resources - may be in hub or workload resource group
  applicationInsights: 'appi-${resourceToken}'
  logAnalyticsWorkspace: 'log-${resourceToken}'

  // Workload resources
  resourceGroup: '${resourceGroupPrefix}-workload'
}

// ========================================================================
// OUTPUTS
// ========================================================================

output resourceToken string = resourceToken

output resourceNames object = {
    // Hub network resources
    hubBastionHost: contains(overrides, 'hubBastionHost') && !empty(overrides.hubBastionHost) ? overrides.hubBastionHost : defaultResourceNames.hubBastionHost
    hubBastionPublicIpAddress: contains(overrides, 'hubBastionPublicIpAddress') && !empty(overrides.hubBastionPublicIpAddress) ? overrides.hubBastionPublicIpAddress : defaultResourceNames.hubBastionPublicIpAddress
    hubBudget: contains(overrides, 'hubBudget') && !empty(overrides.hubBudget) ? overrides.hubBudget : defaultResourceNames.hubBudget
    hubDDoSProtectionPlan: contains(overrides, 'hubDDoSProtectionPlan') && !empty(overrides.hubDDoSProtectionPlan) ? overrides.hubDDoSProtectionPlan : defaultResourceNames.hubDDoSProtectionPlan
    hubFirewall: contains(overrides, 'hubFirewall') && !empty(overrides.hubFirewall) ? overrides.hubFirewall : defaultResourceNames.hubFirewall
    hubFirewallPublicIpAddress: contains(overrides, 'hubFirewallPublicIpAddress') && !empty(overrides.hubFirewallPublicIpAddress) ? overrides.hubFirewallPublicIpAddress : defaultResourceNames.hubFirewallPublicIpAddress
    hubJumphost: contains(overrides, 'hubJumphost') && !empty(overrides.hubJumphost) ? overrides.hubJumphost : defaultResourceNames.hubJumphost
    hubKeyVault: contains(overrides, 'hubKeyVault') && !empty(overrides.hubKeyVault) ? overrides.hubKeyVault : defaultResourceNames.hubKeyVault
    hubResourceGroup: contains(overrides, 'hubResourceGroup') && !empty(overrides.hubResourceGroup) ? overrides.hubResourceGroup : defaultResourceNames.hubResourceGroup
    hubRouteTable: contains(overrides, 'hubRouteTable') && !empty(overrides.hubRouteTable) ? overrides.hubRouteTable : defaultResourceNames.hubRouteTable
    hubSubnetBastionHost: contains(overrides, 'hubSubnetBastionHost') && !empty(overrides.hubSubnetBastionHost) ? overrides.hubSubnetBastionHost : defaultResourceNames.hubSubnetBastionHost
    hubSubnetFirewall: contains(overrides, 'hubSubnetFirewall') && !empty(overrides.hubSubnetFirewall) ? overrides.hubSubnetFirewall : defaultResourceNames.hubSubnetFirewall
    hubSubnetJumphost: contains(overrides, 'hubSubnetJumphost') && !empty(overrides.hubSubnetJumphost) ? overrides.hubSubnetJumphost : defaultResourceNames.hubSubnetJumphost
    hubVirtualNetwork: contains(overrides, 'hubVirtualNetwork') && !empty(overrides.hubVirtualNetwork) ? overrides.hubVirtualNetwork : defaultResourceNames.hubVirtualNetwork
  
    // Common services - may be in hub or workload resource group
    applicationInsights: contains(overrides, 'applicationInsights') && !empty(overrides.applicationInsights) ? overrides.applicationInsights : defaultResourceNames.applicationInsights
    logAnalyticsWorkspace: contains(overrides, 'logAnalyticsWorkspace') && !empty(overrides.logAnalyticsWorkspace) ? overrides.logAnalyticsWorkspace : defaultResourceNames.logAnalyticsWorkspace

    // Workload resources
    resourceGroup: contains(overrides, 'resourceGroup') && !empty(overrides.resourceGroup) ? overrides.resourceGroup : defaultResourceNames.resourceGroup
}
