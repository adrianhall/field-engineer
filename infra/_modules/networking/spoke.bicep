targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Spoke Networking Resources
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

/*
** From: infra/_types/DeploymentSettings.bicep
*/
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', we are deploying hub network resources.')
  deployHubNetwork: bool

  @description('If \'true\', we are deploying a jump host.')
  deployJumphost: bool

  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', all resources should be secured with a virtual network.')
  isNetworkIsolated: bool

  @description('If \'true\', the jump host should have a public IP address.')
  jumphostIsPublic: bool

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The common tags that should be used for all created resources')
  tags: object
  
  @description('If \'true\', use a common app service plan for workload app services.')
  useCommonAppServicePlan: bool
}

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
** From infra/_types/NetworkSettings.bicep
*/
@description('Type that describes the network settings for a single network')
type NetworkSettings = {
  @description('The address space for the virtual network')
  addressSpace: string

  @description('The list of subnets, with their associated address prefixes')
  addressPrefixes: object
}

// ========================================================================
// PARAMETERS
// ========================================================================


@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The global diagnostic settings')
param diagnosticSettings DiagnosticSettings

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The network settings for the hub network')
param networkSettings NetworkSettings

@description('The list of resource names to use')
param resourceNames object

/*
** Dependencies
*/
@description('If set, the hub resource group name that will be used for peering')
param hubResourceGroupName string = ''

@description('If set, the hub virtual network name that will be used for peering')
param hubVirtualNetworkName string = ''

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The resource group name for the spoke networking resources')
param resourceGroupName string = ''

@description('If set, the route table holding the outbound route for the hub network')
param routeTableId string = ''

/*
** Module specific settings
*/
@description('If true, peer to the hub network.  If false, we\'re assuming you will deal with this separately.')
param peerToHubNetwork bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'spoke-network' })

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
}

// ========================================================================
// FEATURE MODULES
// ========================================================================

module spokeNetwork '../../_features/networking/spoke-network.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'spoke-resources'
  scope: spokeResourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    networkSettings: networkSettings
    resourceNames: resourceNames
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    routeTableId: routeTableId

    // Settings
    privateDnsZones: [
      'privatelink.azconfig.io'
      'privatelink.vaultcore.azure.net'
      'privatelink${az.environment().suffixes.sqlServerHostname}'
      'privatelink.azurewebsites.net'
    ]
  }
}

module peerNetworks '../../_features/networking/peer-networks.bicep' = if (peerToHubNetwork && !empty(hubResourceGroupName) && !empty(hubVirtualNetworkName)) {
  name: 'peer-networks'
  scope: subscription()
  params: {
    hubResourceGroupName: hubResourceGroupName
    hubVirtualNetworkName: hubVirtualNetworkName
    spokeResourceGroupName: spokeResourceGroup.name
    spokeVirtualNetworkName: deploymentSettings.isNetworkIsolated ? spokeNetwork.outputs.virtual_network_name : ''
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output resource_group_name string = deploymentSettings.isNetworkIsolated ? spokeNetwork.outputs.resource_group_name : ''
output virtual_network_name string = deploymentSettings.isNetworkIsolated ? spokeNetwork.outputs.virtual_network_name : ''
