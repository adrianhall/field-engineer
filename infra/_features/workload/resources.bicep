targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resource Deployment
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

@description('The list of tags to configure on each created resource.')
param tags object

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
// AZURE MODULES
// ========================================================================

module ownerManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'owner-managed-identity'
  params: {
    name: resourceNames.ownerManagedIdentity
    location: location
    tags: tags
  }
}

module apiManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'api-managed-identity'
  params: {
    name: resourceNames.apiManagedIdentity
    location: location
    tags: tags
  }
}

module webManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'web-managed-identity'
  params: {
    name: resourceNames.webManagedIdentity
    location: location
    tags: tags
  }
}

module configurationFeature './configuration.bicep' = {
  name: 'workload-configuration-module'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    resourceNames: resourceNames
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeConfigurationSubnet
      outboundSubnetName: ''
      virtualNetworkName: virtualNetworkName
      resourceGroupName: networkingResourceGroupName
    } : {}
    ownerIdentities: [
      { principalId: deploymentSettings.principalId,            principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    readerIdentities: [
      { principalId: apiManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
      { principalId: webManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
    ]
  }
}

module storageFeature './storage.bicep' = {
  name: 'workload-storage-module'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    resourceNames: resourceNames
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeStorageSubnet
      outboundSubnetName: ''
      virtualNetworkName: virtualNetworkName
      resourceGroupName: networkingResourceGroupName
    } : {}
    ownerManagedIdentityName: ownerManagedIdentity.outputs.name
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

module commonAppServicePlan '../../_azure/hosting/app-service-plan.bicep' = if (deploymentSettings.useCommonAppServicePlan) {
  name: 'workload-common-app-service-plan'
  params: {
    location: location
    name: resourceNames.commonAppServicePlan
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    autoScaleSettings: deploymentSettings.isProduction ? { maxCapacity: 10, minCapacity: 2 } : {}
    diagnosticSettings: diagnosticSettings
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module apiServiceFeature './app-service.bicep' = {
  name: 'workload-apiservice-module'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    tags: tags

    // Dependencies
    applicationInsightsName: applicationInsightsName
    applicationInsightsResourceGroupName: azureMonitorResourceGroupName
    appConfigurationName: configurationFeature.outputs.app_configuration_name
    appServicePlanName: deploymentSettings.useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.apiAppServicePlan
    keyVaultName: configurationFeature.outputs.key_vault_name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: apiManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.apiAppService
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeApiInboundSubnet
      outboundSubnetName: resourceNames.spokeApiOutboundSubnet
      virtualNetworkName: virtualNetworkName
      resourceGroupName: networkingResourceGroupName
    } : {}
    privateEndpointName: resourceNames.apiPrivateEndpoint
    servicePrefix: 'api'
  }
}

module webServiceFeature './app-service.bicep' = {
  name: 'workload-webservice-module'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    location: location
    tags: tags

    // Dependencies
    applicationInsightsName: applicationInsightsName
    applicationInsightsResourceGroupName: azureMonitorResourceGroupName
    appConfigurationName: configurationFeature.outputs.app_configuration_name
    appServicePlanName: deploymentSettings.useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    keyVaultName: configurationFeature.outputs.key_vault_name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: webManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.apiAppService
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeWebInboundSubnet
      outboundSubnetName: resourceNames.spokeWebOutboundSubnet
      virtualNetworkName: virtualNetworkName
      resourceGroupName: networkingResourceGroupName
    } : {}
    privateEndpointName: resourceNames.webPrivateEndpoint
    servicePrefix: 'web'
  }
}

module gatewayFeature './gateway.bicep' = {
  name: 'workload-gateway-module'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: resourceNames
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    frontDoorRoutes: [
      { name: 'api', serviceAddress: apiServiceFeature.outputs.app_service_hostname, routePattern: '/api/*', privateEndpointResourceId: apiServiceFeature.outputs.app_service_id }
      { name: 'web', serviceAddress: webServiceFeature.outputs.app_service_hostname, routePattern: '/*',     privateEndpointResourceId: webServiceFeature.outputs.app_service_id }
    ]
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output owner_managed_identity_id string = ownerManagedIdentity.outputs.id
output service_api_endpoints string[] = [ '${gatewayFeature.outputs.uri}/api', apiServiceFeature.outputs.app_service_uri ]
output service_web_endpoints string[] = [ gatewayFeature.outputs.uri, webServiceFeature.outputs.app_service_uri ]
