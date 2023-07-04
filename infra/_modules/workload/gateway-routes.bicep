targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resource Deployment - Gateway Resources
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

type FrontDoorRoute = {
  @description('The name of the route; used as a prefix for resources.')
  name: string

  @description('The host name to forward requests to.')
  serviceAddress: string

  @description('The route pattern to use to forward requests to the service.')
  routePattern: string

  @description('If using private endpoints, the ID of the associated resource')
  privateEndpointResourceId: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

/*
** Dependencies
*/
@description('The name of the Azure Front Door Endpoint to configure')
param frontDoorEndpointName string

@description('The name of the Azure Front Door Profile to configure')
param frontDoorProfileName string

@description('The owner managed identity name')
param managedIdentityName string

/*
** Settings
*/
@description('The list of Azure Front Door routes to install')
param frontDoorRoutes FrontDoorRoute[]

// ========================================================================
// AZURE MODULES
// ========================================================================

module frontDoorRoute '../../_azure/security/front-door-route.bicep' = [ for r in frontDoorRoutes: {
  name: '${r.name}-front-door-route'
  params: {
    frontDoorEndpointName: frontDoorEndpointName
    frontDoorProfileName: frontDoorProfileName
    originPrefix: r.name
    serviceAddress: r.serviceAddress
    routePattern: r.routePattern
    privateLinkSettings: deploymentSettings.isNetworkIsolated && !empty(r.privateEndpointResourceId) ? {
      privateEndpointResourceId: r.privateEndpointResourceId
      linkResourceType: 'sites'
      location: deploymentSettings.location
    } : {}
  }
}]

module approveRoute '../../_azure/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'approve-front-door-endpoints'
  params: {
    location: deploymentSettings.location
    managedIdentityName: managedIdentityName
  }
}
