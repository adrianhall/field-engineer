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
@description('The name of the App Service plan resource')
param appServicePlanName string

@description('The name of the Azure Function App resource')
param functionAppName string

@description('The name of the Azure Storage Account resource')
param storageAccountName string

/*
** Dependencies
*/
@description('The name of the Application Configuration resource')
param appConfigurationName string

@description('The name of the Key Vault resource')
param keyVaultName string

@description('The name of the managed identity for this service')
param managedIdentityName string

/*
** Resources to potentially create
*/
@description('The name of the Application Insights resource')
param applicationInsightsName string

@description('The name of the SQL Database resource to create')
param sqlDatabaseName string

@description('The name of the SQL Server resource to use or create')
param sqlServerName string

/*
** Service settings
*/
@description('The network isolation settings for this architectural component')
param networkIsolationSettings NetworkIsolationSettings = {}

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var moduleTags = union(environment.tags, { 'azd-architectural-component': 'devops' })
var servicePrefix = 'devops'
var dataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

module appServicePlan '../azure/hosting/app-service-plan.bicep' = {
  name: '${servicePrefix}-app-service-plan'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: appServicePlanName
    tags: moduleTags

    // Service settings
    sku: 'EP1'
  }
}

module storageAccount '../azure/storage/storage-account.bicep' = {
  name: '${servicePrefix}-storage'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: storageAccountName
    tags: moduleTags

    // Service settings
    managedIdentityName: managedIdentityName
    principalId: environment.principalId
  }
}

module grantDataOwnerToManagedIdentity '../azure/identity/role-assignment.bicep' = {
  name: '${servicePrefix}-grant-data-owner-to-managed-identity'
  params: {
    managedIdentityName: managedIdentityName
    resourceToken: environment.resourceToken
    roleId: dataOwnerRoleId
  }
}

module functionApp '../azure/hosting/function-app.bicep' = {
  name: '${servicePrefix}-function-app'
  params: {
    diagnosticSettings: diagnosticSettings
    networkIsolationSettings: networkIsolationSettings
    location: environment.location
    name: functionAppName
    tags: moduleTags

    appServicePlanName: appServicePlan.outputs.name
    managedIdentityName: managedIdentityName
    storageAccountName: storageAccount.outputs.name

    appSettings: {
      // Application Insights
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey

      // App Configuration and Key Vault
      'Azure:AppConfiguration:Endpoint': appConfiguration.properties.endpoint
      'Azure:KeyVault:Endpoint': keyVault.properties.vaultUri

      // SQL Database and Server
      'Azure:Sql:DatabaseName': sqlDatabaseName
      'Azure:Sql:ServerName': sqlServerName
    }
    enablePublicNetworkAccess: true
    runtime: 'node'
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output app_service_plan_name string = appServicePlan.outputs.name
output function_app_name string = functionApp.outputs.name
output storage_account_name string = storageAccount.outputs.name

output uri string = functionApp.outputs.uri
