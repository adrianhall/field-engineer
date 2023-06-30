targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Common Resources for the Workload
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

@description('The list of resource names to use')
param resourceNames object

/*
** Dependencies
*/
@description('The name of the Application Insights resource from the hub module.')
param applicationInsightsName string = ''

@description('The name of the resource group where the hub Azure Monitor resources are deployed.')
param azureMonitorResourceGroupName string = ''

@description('The Resource ID for the Log Analytics Workspace from the hub module.')
param logAnalyticsWorkspaceId string = ''


// ========================================================================
// VARIABLES
// ========================================================================

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'workload' })

var createSpokeResourceGroup = deploymentSettings.isNetworkIsolated && resourceNames.workloadResourceGroup != resourceNames.spokeResourceGroup

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceNames.workloadResourceGroup
  location: location
  tags: moduleTags
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createSpokeResourceGroup) {
  name: resourceNames.spokeResourceGroup
  location: location
  tags: union(deploymentSettings.tags, { 'azd-module': 'spoke-network' })
}

module azureMonitor '../../_features/monitoring/azure-monitor.bicep' = if (!deploymentSettings.deployHubNetwork) {
  name: 'common-azure-monitor'
  scope: workloadResourceGroup
  params: {
    location: location
    resourceNames: resourceNames
    tags: moduleTags
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output workload_resource_group_name string = workloadResourceGroup.name
output spoke_resource_group_name string = createSpokeResourceGroup ? spokeResourceGroup.name : workloadResourceGroup.name

output azure_monitor_resource_group_name string = !deploymentSettings.deployHubNetwork ? azureMonitor.outputs.resource_group_name : azureMonitorResourceGroupName
output application_insights_name string = !deploymentSettings.deployHubNetwork ? azureMonitor.outputs.application_insights_name : applicationInsightsName
output log_analytics_workspace_id string = !deploymentSettings.deployHubNetwork ? azureMonitor.outputs.log_analytics_workspace_id : logAnalyticsWorkspaceId
