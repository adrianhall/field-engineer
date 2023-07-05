targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resource Deployment - App Service Resources
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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
** From infra/_types/NetworkIsolationSettings.bicep
*/
@description('A type describing the network isolation settings for a module.')
type NetworkIsolationSettings = {
  @description('The name of the private endpoint subnet, for inbound traffic')
  inboundSubnetName: string

  @description('The name of the VNET integration subnet, for outbound traffic')
  outboundSubnetName: string

  @description('The name of the virtual network holding the subnets')
  virtualNetworkName: string

  @description('The resource group holding the virtual network')
  resourceGroupName: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The global diagnostic settings')
param diagnosticSettings DiagnosticSettings

@description('The tags to use for the created resources')
param tags object = {}

/*
** Dependencies
*/
@description('The Application Insights resource to use for logging')
param applicationInsightsName string

@description('The App Configuration resource to use for configuration')
param appConfigurationName string

@description('The name of the App Service Plan to use for compute')
param appServicePlanName string

@description('The name of the resource group holding the Application Insights resource')
param azureMonitorResourceGroupName string

@description('The name of the Key Vault for secrets')
param keyVaultName string

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The name of the managed identity to use for authorizing to other resources')
param managedIdentityName string

/*
** Settings
*/
@description('The name of the App Service to create')
param appServiceName string

@description('The network isolation settings to use')
param networkIsolationSettings NetworkIsolationSettings?

@description('The name of the private endpoint, if network isolation is enabled')
param privateEndpointName string = ''

@description('If set, restricts connectivity to only allow connections via the specified Azure Front Door')
param restrictToAzureFrontDoor string = ''

@description('The service prefix to use for this service')
param servicePrefix string

@description('The programming stack to use')
param stack string = 'DOTNET|6.0'

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

var inboundSubnetId = networkIsolationSettings != null ? resourceId(networkIsolationSettings!.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', networkIsolationSettings!.virtualNetworkName, networkIsolationSettings!.inboundSubnetName ?? '') : ''
var outboundSubnetId = networkIsolationSettings != null ? resourceId(networkIsolationSettings!.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', networkIsolationSettings!.virtualNetworkName, networkIsolationSettings!.outboundSubnetName ?? '') : ''

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
  scope: resourceGroup(azureMonitorResourceGroupName)
}

// =====================================================================================================================
//     AZURE MODULES
// =====================================================================================================================

module appServicePlan '../../_azure/hosting/app-service-plan.bicep' = if (!deploymentSettings.useCommonAppServicePlan) {
  name: '${servicePrefix}-app-service-plan'
  params: {
    location: deploymentSettings.location
    name: appServicePlanName
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

module appService '../../_azure/hosting/app-service.bicep' = {
  name: '${servicePrefix}-app-service'
  params: {
    location: deploymentSettings.location
    name: appServiceName
    tags: tags

    // Dependencies
    appServicePlanName: deploymentSettings.useCommonAppServicePlan ? appServicePlanName : appServicePlan.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: managedIdentityName
    subnetResourceId: deploymentSettings.isNetworkIsolated ? outboundSubnetId : ''

    // Setttings
    appSettings: {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      ASPNETCORE_ENVIRONMENT: deploymentSettings.isProduction ? 'Production' : 'Development'

      // Application Insights
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey

      // App Configuration and Key Vault
      'Azure:AppConfiguration:Endpoint': appConfiguration.properties.endpoint
      'Azure:KeyVault:Endpoint': keyVault.properties.vaultUri
    }
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    linuxFxVersion: stack
    ipSecurityRestrictions: !empty(restrictToAzureFrontDoor) ? [
      {
        tag: 'ServiceTag'
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        priority: 100
        headers: {
          'x-azure-fdid': [ restrictToAzureFrontDoor ]
        }
        name: 'Allow traffic from Front Door'
      }
    ] : []
    servicePrefix: servicePrefix
  }
}

module privateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (networkIsolationSettings != null) {
  name: '${appServiceName}-private-endpoint'
  scope: resourceGroup(networkIsolationSettings!.resourceGroupName)
  params: {
    name: privateEndpointName
    location: deploymentSettings.location
    tags: tags

    // Dependencies
    linkServiceId: appService.outputs.id
    linkServiceName: appService.outputs.name
    subnetResourceId: inboundSubnetId

    // Settings
    dnsZoneName: 'privatelink.azurewebsites.net'
    groupIds: [ 'sites' ]
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output app_service_id string = appService.outputs.id
output app_service_name string = appService.outputs.name
output app_service_hostname string = appService.outputs.hostname
output app_service_uri string = appService.outputs.uri
