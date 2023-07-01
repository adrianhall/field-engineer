targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Hub Networking Resources
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
@description('The name of the Application Insights resource.')
param applicationInsightsName string

@description('The resource group holding the Azure Monitor resources.')
param azureMonitorResourceGroupName string

@description('The ID of the Log Analytics Workspace to send audit and diagnostic data to.')
param logAnalyticsWorkspaceId string

@description('The resource group holding the spoke network resources.')
param networkingResourceGroupName string

@description('The name of the virtual network holding the subnets.')
param virtualNetworkName string

@description('The workload resource group name.')
param workloadResourceGroupName string

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the SQL Administrator; used if creating the server')
param sqlAdministratorPassword string

@minLength(8)
@description('The username for the SQL Administrator; used if creating the server')
param sqlAdministratorUsername string

// ========================================================================
// VARIABLES
// ========================================================================

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'workload' })

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: workloadResourceGroupName
}

// ========================================================================
// FEATURE MODULES
// ========================================================================

module workloadFeature '../../_features/workload/resources.bicep' = {
  name: 'workload-resources'
  scope: workloadResourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    resourceNames: resourceNames
    tags: moduleTags

    // Dependencies
    applicationInsightsName: applicationInsightsName
    azureMonitorResourceGroupName: azureMonitorResourceGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    networkingResourceGroupName: networkingResourceGroupName
    virtualNetworkName: virtualNetworkName

    // Settings
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output service_api_endpoints string[] = workloadFeature.outputs.service_api_endpoints
output service_web_endpoints string[] = workloadFeature.outputs.service_web_endpoints
