targetScope = 'subscription'

/*
** Resource Groups 
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates all the resource groups needed by this deployment
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

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The list of resource names to use')
param resourceNames object

@description('If true, deploy a hub network')
param deployHubNetwork bool

// ========================================================================
// VARIABLES
// ========================================================================

var createHub = deployHubNetwork && resourceNames.hubResourceGroup != resourceNames.resourceGroup
var createSpoke = deploymentSettings.isNetworkIsolated && resourceNames.spokeResourceGroup != resourceNames.resourceGroup

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createHub) {
  name: resourceNames.hubResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, {
    WorkloadName: 'NetworkHub'
    OpsCommitment: 'Platform operations'
  })
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createSpoke) {
  name: resourceNames.spokeResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, deploymentSettings.workloadTags)
}

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceNames.resourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, deploymentSettings.workloadTags)
}
