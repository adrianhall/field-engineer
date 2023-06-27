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

  @description('If using private endpoints, the ID of the associated resource')
  privateEndpointResourceId: string
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

@description('The URI to the key vault')
param keyVaultUri string

@description('The name of the Front Door Endpoint resource to use')
param frontDoorEndpointName string

@description('The name of the Front Door Profile resource to use')
param frontDoorProfileName string

/*
** Settings
*/
@description('The list of configuration settings to install in the configuration stores')
param configurationSettings ConfigurationSetting[]

@description('The list of Azure Front Door routes to install')
param frontDoorRoutes FrontDoorRoute[]

@description('The list of permissions to create for managed identities')
param managedIdentityPermissions ManagedIdentityPermission[]

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// List of managed identities that can access the configuration.
var configurationUsers = map(filter(managedIdentityPermissions, (mi) => !mi.isOwner), (mi) => mi.name)

// List of managed identities that can access the database.
var databaseUsers = map(filter(managedIdentityPermissions, (mi) => !mi.isOwner && mi.isStorageUser), (mi) => mi.name)

// List of values to place in the Key Vault
var keyVaultSecrets = map(filter(configurationSettings, (cs) => cs.secret || cs.private), (cs) => {
  name: replace(cs.name, ':', '--')
  value: cs.value
  content_type: 'text/plain;charset=utf-8'
})

// List of app configuration settings to store
//value: cs.secret ? '{"uri":"${keyVaultUri}secrets/${replace(cs.name, ':', '--)}"}' : cs.value
var appConfigSettings = map(filter(configurationSettings, (cs) => !cs.private), (cs) => {
  name: cs.name
  value: cs.secret ? '{"uri":"${keyVaultUri}secrets/${replace(cs.name,':','--')}"}' : cs.value
  content_type: cs.secret ? 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' : 'text/plain;charset=utf-8'
})

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

// =====================================================================================================================
//     CREATE AZURE KEY VAULT VALUES
// =====================================================================================================================

module kvSecrets './azure/storage/key-vault-secret.bicep' = [ for kv in keyVaultSecrets: {
  name: 'kv-secret-${uniqueString(kv.name)}'
  params: {
    keyVaultName: keyVaultName
    secretName: kv.name
    secretValue: kv.value
  }
}]

/*
** App Configuration does the key-value setting on the data plane, which is not accessible from
** ARM when using network isolation.  We do this a different way when network isolated.
*/
module appConfigKeyValues './azure/storage/app-configuration-keyvalue.bicep' = [ for cs in appConfigSettings: if (!environment.isNetworkIsolated) {
  name: 'appconfig-keyvalue-${uniqueString(cs.name)}'
  params: {
    appConfigurationName: appConfigurationName
    key: cs.name
    value: cs.value
    contentType: cs.content_type
  }
}]

/*
** TODO: When running with network isolation, we use the Azure CLI inside an Azure Container Instance
**  to set the key values.  The ACI is not available unless network isolated.
*/

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
    privateLinkSettings: !empty(r.privateEndpointResourceId) ? {
      privateEndpointResourceId: r.privateEndpointResourceId
      linkResourceType: 'sites'
      location: environment.location
    } : {}
  }
}]

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output configuration_settings object[] = appConfigSettings
output database_users string[] = databaseUsers
