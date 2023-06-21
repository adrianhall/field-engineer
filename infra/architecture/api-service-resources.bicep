// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type Environment = {
  @description('The name of the Azure Developer environment - user chosen')
  name: string

  @description('If true, we are deploying a production environment.  This is used to size resources appropriately.')
  isProduction: bool

  @description('If true, we want network isolation via a virtual network and private endpoints')
  isNetworkIsolated: bool

  @description('The default region we want the resources to be created in')
  location: string

  @description('The running user/service principal; use a blank string to not use a principalId')
  principalId: string

  @description('A token that is used in generating names for resources.  This is unique to the environment and region')
  resourceToken: string

  @description('A list of default tags to apply to all resources')
  tags: object

  @description('If true, use a common app service plan; if false, create an app service plan per app service')
  useCommonAppServicePlan: bool

  @description('If true, use an existing SQL server; if false, create a new SQL server')
  useExistingSqlServer: bool
}

type DiagnosticSettings = {
  @description('The name of the Log Analytics Workspace')
  logAnalyticsWorkspaceName: string

  @description('The audit log retention policy')
  auditLogRetentionInDays: int

  @description('The diagnostic log retention policy')
  diagnosticLogRetentionInDays: int

  @description('If true, enable audit logging')
  enableAuditLogs: bool

  @description('If true, enable diagnostic logging')
  enableDiagnosticLogs: bool
}

type NetworkIsolationSettings = {
  @description('If set, the name of the inbound private endpoint')
  privateEndpointSubnetName: string?

  @description('If set, the name of the subnet for service connections')
  serviceConnectionSubnetName: string?

  @description('If set, the name of the virtual network to use')
  virtualNetworkName: string?
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The environment we are provisioning for')
param environment Environment

/*
** Resources to potentially create
*/
@description('The name of the App Service Plan resource')
param appServicePlanName string

@description('The name of the App Service resource')
param appServiceName string

@description('The name of the managed identity for this service')
param managedIdentityName string

/*
** Dependencies
*/
@description('The name of the Application Configuration resource')
param appConfigurationName string

@description('The name of the Application Insights resource')
param applicationInsightsName string

@description('The name of the Key Vault resource')
param keyVaultName string

/*
** Service settings
*/
@description('If true, the appServicePlanName exists already.  If false, create a new app service plan')
param useExistingAppServicePlan bool = false

@description('The network isolation settings for this architectural component')
param networkIsolationSettings NetworkIsolationSettings = {}

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var servicePrefix = 'api'

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
}

module managedIdentity '../azure/identity/managed-identity.bicep' = {
  name: '${servicePrefix}-managed-identity'
  params: {
    location: environment.location
    name: managedIdentityName
    tags: environment.tags
  }
}

module appServicePlan '../azure/hosting/app-service-plan.bicep' = if (!useExistingAppServicePlan) {
  name: '${servicePrefix}-app-service-plan'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: appServicePlanName
    tags: environment.tags

    // Service settings
    autoScaleSettings: environment.isProduction ? { minimumCapacity: 2, maximumCapacity: 10 } : {}
    sku: environment.isProduction ? 'P1v3' : 'B1'
  }
}

module appService '../azure/hosting/app-service.bicep' = {
  name: '${servicePrefix}-app-service'
  params: {
    diagnosticSettings: diagnosticSettings
    networkIsolationSettings: networkIsolationSettings
    location: environment.location
    name: appServiceName
    tags: union(environment.tags, { 'azd-service-name': servicePrefix })

    // Dependencies
    appServicePlanName: useExistingAppServicePlan ? appServicePlanName : appServicePlan.outputs.name
    managedIdentityName: managedIdentity.outputs.name

    // Service settings
    appSettings: {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      ASPNETCORE_ENVIRONMENT: environment.isProduction ? 'Production' : 'Development'

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
  }
}

module privateEndpoint '../azure/network/private-endpoint.bicep' = if (contains(networkIsolationSettings, 'privateEndpointSubnetName')) {
  name: '${servicePrefix}-app-service-private-endpoint'
  params: {
    name: 'private-endpoint-${appService.outputs.name}'
    location: environment.location
    tags: environment.tags
    dnsZoneName: 'privatelink.azurewebsites.net'
    groupIds: [ 'sites' ]
    linkServiceName: appService.outputs.name
    linkServiceId: appService.outputs.id
    subnetName: networkIsolationSettings.privateEndpointSubnetName ?? ''
    virtualNetworkName: networkIsolationSettings.virtualNetworkName ?? ''
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output app_service_plan_name string = useExistingAppServicePlan ? appServicePlanName : appServicePlan.outputs.name
output app_service_id string = appService.outputs.id
output app_service_name string = appService.outputs.name
output managed_identity_name string = managedIdentity.outputs.name
output private_endpoint_resource_id string = contains(networkIsolationSettings, 'privateEndpointSubnetName') ? privateEndpoint.outputs.id : ''

output hostname string = appService.outputs.hostname
output uri string = appService.outputs.uri
