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
  deploymentSettings.isNetworkIsolated ? [ resourceNames.spokeResourceGroup ] : []
)

/*
** To construct the budget, we use the approximate values from the pricing
** calculator for each resource in the application.  There are different SKUs
** in play for development vs. production.  These prices are for USD in south
** central US region.
**
** This is NOT the entire cost.  It does not include the cost of the hub network,
** for example.
*/
var budgetValues = {
  dev: {
    frontdoor: 40
    appserviceplan: 55
    sqldatabase: 5
    keyvault: 0
    appconfig: 0
    virtualnetwork: 5
    privatelink: 40
  }
  prod: {
    frontdoor: 350
    appserviceplan: 255
    sqldatabase: 460
    keyvault: 0
    appconfig: 36
    virtualnetwork: 5
    privatelink: 40
  }
}

var budgetRecords = deploymentSettings.isProduction ? budgetValues.prod : budgetValues.dev

var budgetAmount = reduce([
  budgetRecords.frontdoor
  deploymentSettings.useCommonAppServicePlan ? budgetRecords.appserviceplan * 2 : budgetRecords.appserviceplan
  budgetRecords.sqldatabase
  budgetRecords.keyvault
  budgetRecords.appconfig
  deploymentSettings.isNetworkIsolated ? budgetRecords.privatelink : 0
  deploymentSettings.isNetworkIsolated ? budgetRecords.virtualnetwork : 0
], 0, (cur, next) => cur + next)

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
    amount: budgetAmount
    contactEmails: [ deploymentSettings.tags['azd-owner-email'] ]
    resourceGroups: resourceGroups
  }
}
