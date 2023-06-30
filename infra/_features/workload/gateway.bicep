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

// =====================================================================================================================
//     PARAMETERS - ALL PARAMETERS ARE REQUIRED IN MODULES
// =====================================================================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The global diagnostic settings')
param diagnosticSettings DiagnosticSettings

@description('The names of all the resources')
param resourceNames object

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The list of tags to configure on each created resource.')
param tags object

/*
** Dependencies
*/
@description('The ID of the Log Analytics Workspace to send audit and diagnostic data to.')
param logAnalyticsWorkspaceId string

@description('The owner managed identity name')
param managedIdentityName string

/*
** Settings
*/
@description('The list of Azure Front Door routes to install')
param frontDoorRoutes FrontDoorRoute[]

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module frontDoor '../../_azure/security/front-door-with-waf.bicep' = {
  name: 'front-door-with-waf'
  params: {
    frontDoorEndpointName: resourceNames.frontDoorEndpoint
    frontDoorProfileName: resourceNames.frontDoorProfile
    webApplicationFirewallName: resourceNames.webApplicationFirewall
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Service settings
    diagnosticSettings: diagnosticSettings
    managedRules: deploymentSettings.isProduction ? [
      { name: 'Microsoft_DefaultRuleSet', version: '2.0' }
      { name: 'Microsoft_BotManager_RuleSet', version: '1.0' }
    ] : []
    sku: deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated ? 'Premium' : 'Standard'
  }
}

module frontDoorRoute '../../_azure/security/front-door-route.bicep' = [ for r in frontDoorRoutes: {
  name: '${r.name}-front-door-route'
  params: {
    frontDoorEndpointName: frontDoor.outputs.endpoint_name
    frontDoorProfileName: frontDoor.outputs.profile_name
    originPrefix: r.name
    serviceAddress: r.serviceAddress
    routePattern: r.routePattern
    privateLinkSettings: deploymentSettings.isNetworkIsolated && !empty(r.privateEndpointResourceId) ? {
      privateEndpointResourceId: r.privateEndpointResourceId
      linkResourceType: 'sites'
      location: location
    } : {}
  }
}]

module approveRoute '../../_azure/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'approve-front-door-endpoints'
  params: {
    location: location
    managedIdentityName: managedIdentityName
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output front_door_endpoint_name string = frontDoor.outputs.endpoint_name
output front_door_profile_name string = frontDoor.outputs.profile_name
output web_application_firewall_name string = frontDoor.outputs.waf_name

output hostname string = frontDoor.outputs.hostname
output uri string = frontDoor.outputs.uri
