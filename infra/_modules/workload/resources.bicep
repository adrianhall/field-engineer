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
param diagnosticSettings DiagnosticSettings

@description('The list of resource names to use')
param resourceNames object


/*
** Dependencies
*/
@description('The subnet ID for the configuration subnet, or \'\' if not using a virtual network')
param configurationSubnetId string = ''

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The subnet ID for the storage subnet, or \'\' if not using a virtual network')
param storageSubnetId string = ''

/*
** Module specific settings
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

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'spoke', 'azd-function': 'application' })

// Determines if we should create a SQL server or use an existing one.
var createSqlServer = resourceNames.sqlResourceGroup == resourceNames.resourceGroup

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.resourceGroup
}

resource sqlResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = if (!createSqlServer) {
  name: resourceNames.sqlResourceGroup
}

resource existingSqlServer 'Microsoft.Sql/servers@2021-11-01' existing = if (!createSqlServer) {
  name: resourceNames.sqlServer
  scope: sqlResourceGroup
}

// ========================================================================
// AZURE MODULES
// ========================================================================

/*
** We use managed identities for authorizing connectivity between resources.
*/
module ownerManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'owner-managed-identity'
  scope: resourceGroup
  params: {
    name: resourceNames.ownerManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module apiManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'api-managed-identity'
  scope: resourceGroup
  params: {
    name: resourceNames.apiManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module webManagedIdentity '../../_azure/identity/managed-identity.bicep' = {
  name: 'web-managed-identity'
  scope: resourceGroup
  params: {
    name: resourceNames.webManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

/*
** The configuration layer takes care of storing configuration data that the web and
** API layer will use in running the application.  There are two components:
**
**  App Configuration - non-secret values and feature flags
**  Key Vault - secrets
*/
module appConfiguration '../../_azure/storage/app-configuration.bicep' = {
  name: 'workload-app-configuration'
  scope: resourceGroup
  params: {
    name: resourceNames.appConfiguration
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    ownerIdentities: [
      { principalId: deploymentSettings.principalId,            principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    readerIdentities: [
      { principalId: apiManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
      { principalId: webManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
    ]

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.appConfigurationPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: configurationSubnetId
    } : null
    sku: deploymentSettings.isNetworkIsolated ? 'Standard' : 'Free'
  }
}

module keyVault '../../_azure/security/key-vault.bicep' = {
  name: 'workload-key-vault'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    ownerIdentities: [
      { principalId: deploymentSettings.principalId,            principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    readerIdentities: [
      { principalId: apiManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
      { principalId: webManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal' }
    ]

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: configurationSubnetId
    } : null
  }
}

/*
** Our storage layer consists of a SQL server and database.  There are various reasons
** why we may want to configure a SQL database on a pre-existing server, so we've allowed
** for that by setting a sqlResourceGroup in the naming overrides.  If it's different
** from our workload resource group, we assume it exists already.
*/
module sqlServer '../../_azure/database/sql-server.bicep' = if (createSqlServer) {
  name: 'workload-sql-server'
  scope: resourceGroup
  params: {
    name: resourceNames.sqlServer
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

module sqlDatabase '../../_azure/database/sql-database.bicep' = {
  name: 'workload-sql-database'
  scope: resourceGroup
  params: {
    name: resourceNames.sqlDatabase
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sqlServerName: createSqlServer ? sqlServer.outputs.name : existingSqlServer.name

    // Settings
    diagnosticSettings: diagnosticSettings
    dtuCapacity: deploymentSettings.isProduction ? 125 : 10
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.sqlDatabasePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: storageSubnetId
    } : null
    sku: deploymentSettings.isProduction ? 'Premium' : 'Standard'
    zoneRedundant: deploymentSettings.isProduction
  }
}

/*
** If we created the SQL server, write the administrator information into Key Vault
*/
module writeSqlAdminInfo '../../_azure/security/key-vault-secrets.bicep' = if (createSqlServer) {
  name: 'write-sql-admin-info-to-keyvault'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    secrets: [
      { key: 'FieldEngineer--SqlAdministratorUsername', value: sqlAdministratorUsername }
      { key: 'FieldEngineer--SqlAdministratorPassword', value: sqlAdministratorPassword }
      { key: 'FieldEngineer--SqlConnectionString', value: 'Server=tcp:${sqlServer.outputs.hostname},1433;Database=${sqlDatabase.outputs.name};User ID=${sqlAdministratorUsername};Password=${sqlAdministratorPassword};Trusted_Connection=False;Encrypt=True;' }
    ]
  }
  dependsOn: [
    keyVault
  ]
}

/*
** We can either use a common App Service Plan (which is more cost effective because it
** shares compute resources between the API and Web layers), or we can use separate App
** Service Plans for each service layer.  This configures the common App Service Plan.
*/
module commonAppServicePlan '../../_azure/hosting/app-service-plan.bicep' = if (deploymentSettings.useCommonAppServicePlan) {
  name: 'workload-common-app-service-plan'
  scope: resourceGroup
  params: {
    name: resourceNames.commonAppServicePlan
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    autoScaleSettings: deploymentSettings.isProduction ? { maxCapacity: 10, minCapacity: 2 } : {}
    diagnosticSettings: diagnosticSettings
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}

/*
** We secure inbound web traffic with a gateway - the Azure Front Door service.
*/
module frontDoor '../../_azure/security/front-door-with-waf.bicep' = {
  name: 'front-door-with-waf'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: resourceNames.frontDoorEndpoint
    frontDoorProfileName: resourceNames.frontDoorProfile
    webApplicationFirewallName: resourceNames.webApplicationFirewall
    location: deploymentSettings.location
    tags: moduleTags

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

/*
** The API and Web layers are identical in terms of configuration, so we use a common module
** to set them up.
*/
module apiService './app-service.bicep' = {
  name: 'workload-apiservice'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    tags: moduleTags
    
    // Dependencies
    applicationInsightsName: resourceNames.applicationInsights
    appConfigurationName: appConfiguration.outputs.name
    appServicePlanName: deploymentSettings.useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.apiAppServicePlan
    azureMonitorResourceGroupName: deploymentSettings.deployHubNetwork ? resourceNames.hubResourceGroup : resourceNames.resourceGroup
    keyVaultName: keyVault.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: apiManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.apiAppService
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeApiInboundSubnet
      outboundSubnetName: resourceNames.spokeApiOutboundSubnet
      virtualNetworkName: resourceNames.spokeVirtualNetwork
      resourceGroupName: resourceNames.spokeResourceGroup
    } : null
    privateEndpointName: resourceNames.apiPrivateEndpoint
    restrictToAzureFrontDoor: frontDoor.outputs.front_door_id
    servicePrefix: 'api'
  }
  dependsOn: [
    appConfiguration
    keyVault
  ]
}

module webService './app-service.bicep' = {
  name: 'workload-webservice'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    tags: moduleTags
    
    // Dependencies
    applicationInsightsName: resourceNames.applicationInsights
    appConfigurationName: appConfiguration.outputs.name
    appServicePlanName: deploymentSettings.useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    azureMonitorResourceGroupName: deploymentSettings.deployHubNetwork ? resourceNames.hubResourceGroup : resourceNames.resourceGroup
    keyVaultName: keyVault.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: webManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppService
    networkIsolationSettings: deploymentSettings.isNetworkIsolated ? {
      inboundSubnetName: resourceNames.spokeWebInboundSubnet
      outboundSubnetName: resourceNames.spokeWebOutboundSubnet
      virtualNetworkName: resourceNames.spokeVirtualNetwork
      resourceGroupName: resourceNames.spokeResourceGroup
    } : null
    privateEndpointName: resourceNames.webPrivateEndpoint
    restrictToAzureFrontDoor: frontDoor.outputs.front_door_id
    servicePrefix: 'web'
  }
}

/*
** Now that we have both the Azure Front Door and the API/web services setup, we
** can route traffic from the front door to the web services.
*/
module gatewayRoutes './gateway-routes.bicep' = {
  name: 'workload-gateway-routes'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings

    // Dependencies
    frontDoorEndpointName: frontDoor.outputs.endpoint_name
    frontDoorProfileName: frontDoor.outputs.profile_name
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    frontDoorRoutes: [
      {
        name: 'api'
        serviceAddress: apiService.outputs.app_service_hostname
        routePattern: '/api/*'
        privateEndpointResourceId: apiService.outputs.app_service_id
      }
      {
        name: 'web'
        serviceAddress: webService.outputs.app_service_hostname
        routePattern: '/*'
        privateEndpointResourceId: webService.outputs.app_service_id
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output managed_identity_name string = ownerManagedIdentity.outputs.name
output service_api_endpoints string[] = [ '${frontDoor.outputs.uri}/api', apiService.outputs.app_service_uri ]
output service_web_endpoints string[] = [ frontDoor.outputs.uri, webService.outputs.app_service_uri ]

// Outputs for the post-provision layer
output api_endpoint string = apiService.outputs.app_service_uri
output managed_identities object[] = [
  { name: apiManagedIdentity.outputs.name,   principalId: apiManagedIdentity.outputs.principal_id }
  { name: webManagedIdentity.outputs.name,   principalId: webManagedIdentity.outputs.principal_id }
]
output sql_connection_string string = sqlDatabase.outputs.connection_string
