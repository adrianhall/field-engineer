targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Azure Monitor
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

@description('The name of the resource group to place the resources into.')
param resourceGroupName string

@description('The list of resource names to use')
param resourceNames object

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
}

module logAnalytics '../../_azure/monitoring/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    name: resourceNames.logAnalyticsWorkspace
    tags: deploymentSettings.tags

    // Settings
    sku: 'PerGB2018'
  }
}

module applicationInsights '../../_azure/monitoring/application-insights.bicep' = {
  name: 'application-insights'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    name: resourceNames.applicationInsights
    dashboardName: resourceNames.applicationInsightsDashboard
    tags: deploymentSettings.tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output workspace_id string = logAnalytics.outputs.id
