// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

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

type ConfigurationSetting = {
  @description('The name of the configuration setting')
  name: string

  @description('If true, the setting is private and should not be available to application code.')
  private: bool

  @description('If true, the setting is a secret and should be stored securely.')
  secret: bool

  @description('The value of the configuration setting')
  value: string
}

type FrontDoorRoute = {
  @description('The name of the route; used as a prefix for resources.')
  name: string

  @description('The host name to forward requests to.')
  serviceAddress: string

  @description('The route pattern to use to forward requests to the service.')
  routePattern: string
}

type ManagedIdentityPermission = {
  @description('If true, this managed identity should be given owner privileges.')
  isOwner: bool

  @description('If true, this managed identity should be given access to the storage layer')
  isStorageUser: bool

  @description('The name of the user-defined managed identity')
  name: string
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The environment we are provisioning for')
param environment Environment

/*
** Dependencies
*/
@description('The name of the App Configuration resource to use')
param appConfigurationName string

@description('The name of the Key Vault resource to use')
param keyVaultName string

@description('The name of the Front Door Endpoint resource to use')
param frontDoorEndpointName string

@description('The name of the Front Door Profile resource to use')
param frontDoorProfileName string

@description('The name of the user-defined managed identity that has permission to write to the configuration and database layer')
param managedIdentityName string

@description('The name of the SQL Database resource to use')
param sqlDatabaseName string

@description('The name of the SQL Server resource to use')
param sqlServerName string

/*
** Settings
*/
@description('The list of configuration settings to install in the configuration stores')
param configurationSettings ConfigurationSetting[]

@description('The list of Azure Front Door routes to install')
param frontDoorRoutes FrontDoorRoute[]

@description('The list of permissions to create for managed identities')
param managedIdentityPermissions ManagedIdentityPermission[]

@secure()
@description('The SQL Administrator password.')
param sqlAdministratorPassword string

@description('The SQL Administrator username to use.')
param sqlAdministratorUsername string

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// List of managed identities that can access the configuration.
var configurationUsers = map(filter(managedIdentityPermissions, (mi) => !mi.isOwner), (mi) => mi.name)

// List of managed identities that can access the database.
var databaseUsers = map(filter(managedIdentityPermissions, (mi) => !mi.isOwner && mi.isStorageUser), (mi) => mi.name)

// List of configuration settings that should be placed into key vault and not references in the configuration store.
var kvSecrets = map(filter(configurationSettings, (cs) => cs.private), (cs) => { name: cs.name, value: cs.value })

// List of configuration settings that should be placed into the configuration store directly.
var appConfigSettings = map(filter(configurationSettings, (cs) => !cs.secret && !cs.private), (cs) => { name: cs.name, value: cs.value })

// List of configuration settings that should be placed into the key vault and referenced in the configuration store.
var kvConfigSettings = map(filter(configurationSettings, (cs) => cs.secret && !cs.private), (cs) => { name: cs.name, value: cs.value })

@description('Built in \'App Configuration Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var appConfigurationDataReaderRoleId = '516239f1-63e1-4d78-a4de-a74fb236a071'

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// =====================================================================================================================
//     GRANT ROLES
// =====================================================================================================================

module grantDataReaderRole './azure/identity/role-assignment.bicep' = [ for mi in configurationUsers: {
  name: 'grant-data-reader-to-${mi}'
  params: {
    managedIdentityName: mi
    resourceToken: environment.resourceToken
    roleId: appConfigurationDataReaderRoleId
  }
}]

module grantSecretsUserRole './azure/identity/role-assignment.bicep' = [ for mi in configurationUsers: {
  name: 'grant-secrets-user-to-${mi}'
  params: {
    managedIdentityName: mi
    resourceToken: environment.resourceToken
    roleId: keyVaultSecretsUserRoleId
  }
}]

module grantDatabaseAccess './azure/database/create-sql-managed-identity.bicep' = [ for mi in databaseUsers: {
  name: 'grant-database-access-to-${mi}'
  params: {
    name: 'sql-managed-identity-${mi}'
    location: environment.location
    tags: environment.tags
    administratorManagedIdentityName: managedIdentityName
    managedIdentityName: mi
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
    sqlDatabaseName: sqlDatabaseName
    sqlServerName: sqlServerName
  }
}]

// =====================================================================================================================
//     INJECT CONFIGURATION SETTINGS INTO APP CONFIGURATION AND KEY VAULT
// =====================================================================================================================

module keyVaultSecret './azure/storage/key-vault-secret.bicep' = [ for secret in kvSecrets: {
  name: 'kv-secret-${uniqueString(secret.name)}'
  params: {
    keyVaultName: keyVaultName
    secretName: secret.name
    secretValue: secret.value
  }
}]

module appConfigurationSetting './azure/storage/app-configuration-setting.bicep' = [ for setting in appConfigSettings: {
  name: 'app-config-${uniqueString(setting.name)}'
  params: {
    location: environment.location
    tags: environment.tags
    ownerManagedIdentityName: managedIdentityName
    appConfigurationName: appConfigurationName
    isSecret: false
    keyVaultName: keyVaultName
    settingName: setting.name
    settingValue: setting.value
  }
}]

module kvConfigurationSetting './azure/storage/app-configuration-setting.bicep' = [ for setting in kvConfigSettings: {
  name: 'kv-config-${uniqueString(setting.name)}'
  params: {
    location: environment.location
    tags: environment.tags
    ownerManagedIdentityName: managedIdentityName
    appConfigurationName: appConfigurationName
    isSecret: true
    keyVaultName: keyVaultName
    settingName: setting.name
    settingValue: setting.value
  }
}]

// =====================================================================================================================
//     CREATE AZURE FRONT DOOR CONFIGURATION
// =====================================================================================================================

module frontDoorRoute './azure/security/front-door-route.bicep' = [ for r in frontDoorRoutes: {
  name: '${r.name}-front-door-route'
  params: {
    frontDoorEndpointName: frontDoorEndpointName
    frontDoorProfileName: frontDoorProfileName
    originPrefix: r.name
    serviceAddress: r.serviceAddress
    routePattern: r.routePattern
  }
}]
