targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Resource Naming
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

/*
** This module create a hub network, if it is requested.
*/

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The network settings for the hub network')
param networkSettings NetworkSettings

@description('The list of resource names to use')
param resourceNames object

// ========================================================================
// VARIABLES
// ========================================================================

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'hub-network' })

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (deploymentSettings.deployHubNetwork) {
  name: resourceNames.hubResourceGroup
  location: location
  tags: moduleTags
}

// ========================================================================
// FEATURE MODULES
// ========================================================================

module hubNetwork '../_features/hub-network.bicep' = if (deploymentSettings.deployHubNetwork) {
  name: 'resources'
  scope: hubResourceGroup
  params: {
    deploymentSettings: deploymentSettings
    location: location
    networkSettings: networkSettings
    resourceNames: resourceNames
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output bastion_hostname string = deploymentSettings.deployHubNetwork ? hubNetwork.bastion_hostname : ''
output firewall_hostname string = deploymentSettings.deployHubNetwork ? hubNetwork.firewall_hostname : ''
