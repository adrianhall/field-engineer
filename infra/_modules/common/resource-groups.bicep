targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Resource Naming
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

// ========================================================================
// USER-DEFINED TYPES
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

  @description('The primary Azure region to host resources')
  location: string

  @description('If \'true\', the jump host should have a public IP address.')
  jumphostIsPublic: bool

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

  @description('If \'true\', use a common app service plan for workload app services.')
  useCommonAppServicePlan: bool
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The list of resource names to use')
param resourceNames object

// ========================================================================
// VARIABLES
// ========================================================================

var createHub = deploymentSettings.deployHubNetwork && resourceNames.hubResourceGroup != resourceNames.resourceGroup
var createSpoke = deploymentSettings.isNetworkIsolated && resourceNames.spokeResourceGroup != resourceNames.resourceGroup

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createHub) {
  name: resourceNames.hubResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, { 'azd-module': 'hub', 'azd-function': 'networking' })
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createSpoke) {
  name: resourceNames.spokeResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, { 'azd-module': 'spoke', 'azd-function': 'networking' })
}

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceNames.resourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, { 'azd-module': 'workload', 'azd-function': 'application' })
}
