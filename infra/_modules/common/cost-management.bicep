targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resources
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

/*
** From: infra/_types/DiagnosticSettings.bicep
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
#disable-next-line no-unused-params
param diagnosticSettings DiagnosticSettings

@description('The list of resource names to use')
param resourceNames object

// ========================================================================
// VARIABLES
// ========================================================================

// We use union() to get a unique list of the resource groups to monitor.
var resourceGroups = union(
  [ resourceNames.resourceGroup ],
  deploymentSettings.deployHubNetwork ? [ resourceNames.hubResourceGroup ] : [],
  deploymentSettings.isNetworkIsolated ? [ resourceNames.spokeResourceGroup ] : []
)

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.resourceGroup
}

module budget '../../_azure/cost-management/budget.bicep' = {
  name: 'workload-budget'
  scope: resourceGroup
  params: {
    name: resourceNames.budget
    amount: 1000
    contactEmails: [ deploymentSettings.tags['azd-owner-email'] ]
    resourceGroups: resourceGroups
  }
}
