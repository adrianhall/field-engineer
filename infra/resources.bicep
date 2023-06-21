targetScope = 'resourceGroup'

// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

/*
** The diagnostic settings to use for the application
*/
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

/*
** The environment provides shared information about the environment to produce.
*/
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

/*
** The actual resource names to use for the infrastructure.
*/
type ResourceNames = {
  apiAppService: string
  apiAppServicePlan: string
  apiManagedIdentity: string
  apiManagement: string
  appConfiguration: string
  applicationInsights: string
  applicationInsightsDashboard: string
  applicationOwnerManagedIdentity: string
  commonAppServicePlan: string
  devopsAppServicePlan: string
  devopsFunctionApp: string
  devopsStorageAccount: string
  frontDoorEndpoint: string
  frontDoorProfile: string
  keyVault: string
  logAnalyticsWorkspace: string
  sqlDatabase: string
  sqlServer: string
  virtualNetworkName: string
  webApplicationFirewall: string
  webAppService: string
  webAppServicePlan: string
  webManagedIdentity: string
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for the application')
param diagnosticSettings DiagnosticSettings

@description('The environment we are provisioning for')
param environment Environment

@description('The list of resource names to use.')
param resourceNames ResourceNames

@secure()
@minLength(8)
@description('The SQL Administrator password.')
param sqlAdministratorPassword string

@minLength(8)
@description('The SQL Administrator username to use.')
param sqlAdministratorUsername string

// =====================================================================================================================
//     ARCHITECTURAL COMPONENTS
// =====================================================================================================================

module common './architecture/common-resources.bicep' = {
  name: 'arch-common'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment
    
    // Resource names
    appServicePlanName: resourceNames.commonAppServicePlan
    managedIdentityName: resourceNames.applicationOwnerManagedIdentity
  }
}

module network './architecture/network-isolation.bicep' = {
  name: 'arch-network-isolation'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment

    // Resource names
    virtualNetworkName: resourceNames.virtualNetworkName
  }
}

module configuration './architecture/configuration-resources.bicep' = {
  name: 'arch-configuration'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment
    
    // Resource names
    appConfigurationName: resourceNames.appConfiguration
    keyVaultName: resourceNames.keyVault

    // Dependencies
    managedIdentityPrincipalId: common.outputs.principal_id

    // Network isolation settings
    networkIsolationSettings: environment.isNetworkIsolated ? {
      privateEndpointSubnetName: network.outputs.configuration_subnet_name
      serviceConnectionSubnetName: network.outputs.configuration_subnet_name
      virtualNetworkName: network.outputs.virtual_network_name
    } : {}
  }
}

module storage './architecture/storage-resources.bicep' = {
  name: 'arch-storage'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment

    // Resource names
    sqlDatabaseName: resourceNames.sqlDatabase
    sqlServerName: resourceNames.sqlServer

    // Dependencies
    managedIdentityName: common.outputs.managed_identity_name

    // Settings
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
    useExistingSqlServer: environment.useExistingSqlServer

    // Network isolation settings
    networkIsolationSettings: environment.isNetworkIsolated ? {
      privateEndpointSubnetName: network.outputs.storage_subnet_name
      serviceConnectionSubnetName: network.outputs.storage_subnet_name
      virtualNetworkName: network.outputs.virtual_network_name
    } : {}
  }
}

module apiService './architecture/api-service-resources.bicep' = {
  name: 'arch-api-service'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment

    // Resource names
    appServicePlanName: environment.useCommonAppServicePlan ? resourceNames.commonAppServicePlan : resourceNames.apiAppServicePlan
    appServiceName: resourceNames.apiAppService
    managedIdentityName: resourceNames.apiManagedIdentity
    
    // Dependencies
    appConfigurationName: configuration.outputs.app_configuration_name
    applicationInsightsName: resourceNames.applicationInsights
    keyVaultName: configuration.outputs.key_vault_name

    // Settings
    useExistingAppServicePlan: environment.useCommonAppServicePlan

    // Network isolation settings
    networkIsolationSettings: environment.isNetworkIsolated ? {
      privateEndpointSubnetName: network.outputs.api_inbound_subnet_name
      serviceConnectionSubnetName: network.outputs.api_outbound_subnet_name
      virtualNetworkName: network.outputs.virtual_network_name
    } : {}
  }
}

module webService './architecture/web-service-resources.bicep' = {
  name: 'arch-web-service'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment

    // Resource names
    appServicePlanName: environment.useCommonAppServicePlan ? resourceNames.commonAppServicePlan : resourceNames.webAppServicePlan
    appServiceName: resourceNames.webAppService
    managedIdentityName: resourceNames.webManagedIdentity
    
    // Dependencies
    appConfigurationName: configuration.outputs.app_configuration_name
    applicationInsightsName: resourceNames.applicationInsights
    keyVaultName: configuration.outputs.key_vault_name

    // Settings
    useExistingAppServicePlan: environment.useCommonAppServicePlan
    
    // Network isolation settings
    networkIsolationSettings: environment.isNetworkIsolated ? {
      privateEndpointSubnetName: network.outputs.web_inbound_subnet_name
      serviceConnectionSubnetName: network.outputs.web_outbound_subnet_name
      virtualNetworkName: network.outputs.virtual_network_name
    } : {}
  }
}

module edgeSecurity './architecture/edge-security-resources.bicep' = {
  name: 'arch-edge-security'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment

    // Resource names
    frontDoorEndpointName: resourceNames.frontDoorEndpoint
    frontDoorProfileName: resourceNames.frontDoorProfile
    webApplicationFirewallName: resourceNames.webApplicationFirewall
  }
}

/*
** During the post-provision step, we need to do some things within the confines of the
** VNET.  This module creates a set of temporary resources that we can use to do that.
*/
module devops './architecture/devops-resources.bicep' = {
  name: 'arch-devops-resources'
  params: {
    diagnosticSettings: diagnosticSettings
    environment: environment
    
    // Resource names
    appServicePlanName: resourceNames.devopsAppServicePlan
    functionAppName: resourceNames.devopsFunctionApp
    storageAccountName: resourceNames.devOpsStorageAccount

    // Dependencies
    appConfigurationName: configuration.outputs.app_configuration_name
    applicationInsightsName: resourceNames.applicationInsights
    keyVaultName: configuration.outputs.key_vault_name
    managedIdentityName: common.outputs.managed_identity_name
    sqlServerName: storage.outputs.sql_server_name
    sqlDatabaseName: storage.outputs.sql_database_name

    // Network isolation settings
    networkIsolationSettings: environment.isNetworkIsolated ? {
      privateEndpointSubnetName: network.outputs.web_inbound_subnet_name
      serviceConnectionSubnetName: network.outputs.web_outbound_subnet_name
      virtualNetworkName: network.outputs.virtual_network_name
    } : {}
  }
}

// =====================================================================================================================
//     POST PROVISIONING STEP
// =====================================================================================================================

module postProvision './post-provision.bicep' = {
  name: 'post-provision'
  params: {
    environment: environment

    // Dependencies
    frontDoorEndpointName: edgeSecurity.outputs.front_door_endpoint_name
    frontDoorProfileName: edgeSecurity.outputs.front_door_profile_name
    keyVaultName: configuration.outputs.key_vault_name
    keyVaultUri: configuration.outputs.key_vault_uri
    managedIdentityName: common.outputs.managed_identity_name
    sqlDatabaseName: storage.outputs.sql_database_name
    sqlServerName: storage.outputs.sql_server_name

    // Settings
    configurationSettings: [
      { private: false, secret: false, name: 'FieldEngineer:Api:Endpoint',         value: apiService.outputs.uri }
      { private: false, secret: false, name: 'FieldEngineer:Sql:ConnectionString', value: storage.outputs.connection_string }
      { private: true,  secret: true,  name: 'FieldEngineer:Sql:AdminPassword',    value: sqlAdministratorPassword }
      { private: true,  secret: true,  name: 'FieldEngineer:Sql:AdminUsername',    value: sqlAdministratorUsername }
    ]

    frontDoorRoutes: [
      { name: 'api', serviceAddress: apiService.outputs.hostname, routePattern: '/api/*', privateEndpointResourceId: environment.isNetworkIsolated ? apiService.outputs.app_service_id : '' }
      { name: 'web', serviceAddress: webService.outputs.hostname, routePattern: '/*',     privateEndpointResourceId: environment.isNetworkIsolated ? webService.outputs.app_service_id : '' }
    ]

    managedIdentityPermissions: [
      { name: common.outputs.managed_identity_name,     isOwner: true,  isStorageUser: true  }
      { name: apiService.outputs.managed_identity_name, isOwner: false, isStorageUser: true  }
      { name: webService.outputs.managed_identity_name, isOwner: false, isStorageUser: false }
    ]

    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output service_api_endpoints string[] = [ apiService.outputs.uri ]
output service_web_endpoints string[] = [ edgeSecurity.outputs.uri ]

/*
** Values required by the post-provisioning hook.
*/
output postprovision_configuration object[] = postProvision.outputs.configuration_settings
output postprovision_managed_identities object[] = postProvision.outputs.managed_identity_permissions
output postprovision_settings object = {
  appServicePlanName: devops.outputs.app_service_plan_name
  functionAppName: devops.outputs.function_app_name
  storageAccountName: devops.outputs.storage_account_name
}
