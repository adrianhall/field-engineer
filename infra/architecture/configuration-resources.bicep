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
@description('The name of the App Configuration resource to create')
param appConfigurationName string

@description('The name of the Key Vault resource to create')
param keyVaultName string

/*
** Dependent resources
*/
@description('The Principal ID of the managed identity to use for the application owner')
param managedIdentityPrincipalId string

@description('The network isolation settings for this architectural component')
param networkIsolationSettings NetworkIsolationSettings = {}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module appConfiguration '../azure/storage/app-configuration.bicep' = {
  name: 'config-appconfig'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: appConfigurationName
    tags: environment.tags

    // Dependencies
    managedIdentityPrincipalId: managedIdentityPrincipalId
    principalId: environment.principalId

    // Service settings
    enablePublicNetworkAccess: !environment.isNetworkIsolated
    sku: environment.isNetworkIsolated || environment.isProduction ? 'Standard' : 'Free'
  }
}

module appConfigurationPrivateEndpoint '../azure/network/private-endpoint.bicep' = if (contains(networkIsolationSettings, 'privateEndpointSubnetName')) {
  name: 'config-appconfig-private-endpoint'
  params: {
    name: 'private-endpoint-${appConfiguration.outputs.name}'
    location: environment.location
    tags: environment.tags
    dnsZoneName: 'privatelink.azconfig.io'
    groupIds: [ 'configurationStores' ]
    linkServiceName: appConfiguration.outputs.name
    linkServiceId: appConfiguration.outputs.id
    subnetName: networkIsolationSettings.privateEndpointSubnetName ?? ''
    virtualNetworkName: networkIsolationSettings.virtualNetworkName ?? ''
  }
}

module keyVault '../azure/storage/key-vault.bicep' = {
  name: 'config-keyvault'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: keyVaultName
    tags: environment.tags

    // Dependencies
    managedIdentityPrincipalId: managedIdentityPrincipalId
    principalId: environment.principalId

    // Service settings
    enablePublicNetworkAccess: !environment.isNetworkIsolated
  }
}

module keyVaultPrivateEndpoint '../azure/network/private-endpoint.bicep' = if (contains(networkIsolationSettings, 'privateEndpointSubnetName')) {
  name: 'config-keyvault-private-endpoint'
  params: {
    name: 'private-endpoint-${keyVault.outputs.name}'
    location: environment.location
    tags: environment.tags
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupIds: [ 'vault' ]
    linkServiceName: keyVault.outputs.name
    linkServiceId: keyVault.outputs.id
    subnetName: networkIsolationSettings.privateEndpointSubnetName ?? ''
    virtualNetworkName: networkIsolationSettings.virtualNetworkName ?? ''
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output app_configuration_name string = appConfiguration.outputs.name
output app_configuration_uri string = appConfiguration.outputs.uri

output key_vault_name string = keyVault.outputs.name
output key_vault_uri string = keyVault.outputs.uri
