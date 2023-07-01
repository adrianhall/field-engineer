targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resource Deployment - Configuration Resources
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

/*
** From: infra/_types/ApplicationIdentity.bicep
*/
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User')
  principalType: 'ServicePrincipal' | 'User'
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
@description('The ID of the Log Analytics Workspace to send audit and diagnostic data to.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@description('The network isolation settings to use for this service.')
param networkIsolationSettings NetworkIsolationSettings?

@description('The list of application identities to be granted owner access to the workload resources.')
param ownerIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted reader access to the workload resources.')
param readerIdentities ApplicationIdentity[] = []

// ========================================================================
// VARIABLES
// ========================================================================

@description('Built in \'App Configuration Data Owner\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var dataOwnerRoleId = '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'

@description('Built in \'App Configuration Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var dataReaderRoleId = '516239f1-63e1-4d78-a4de-a74fb236a071'

@description('Built in \'Key Vault Administrator\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

var subnetId = deploymentSettings.isNetworkIsolated && networkIsolationSettings != null ? resourceId(networkIsolationSettings!.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', networkIsolationSettings!.virtualNetworkName, networkIsolationSettings!.inboundSubnetName ?? '') : ''

// ========================================================================
// AZURE MODULES
// ========================================================================

module appConfiguration '../../_azure/storage/app-configuration.bicep' = {
  name: 'workload-app-configuration'
  params: {
    name: resourceNames.appConfiguration
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    sku: deploymentSettings.isNetworkIsolated ? 'Standard' : 'Free'
  }
}

module grantDataOwnerAccess '../../_azure/identity/role-assignment.bicep' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: 'grant-dataowner-${uniqueString(id.principalId)}'
  params: {
    principalId: id.principalId
    principalType: id.principalType
    roleId: dataOwnerRoleId
  }
}]

module grantDataReaderAccess '../../_azure/identity/role-assignment.bicep' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: 'grant-datareader-${uniqueString(id.principalId)}'
  params: {
    principalId: id.principalId
    principalType: id.principalType
    roleId: dataReaderRoleId
  }
}]

module keyVault '../../_azure/security/key-vault.bicep' = {
  name: 'workload-key-vault'
  params: {
    name: resourceNames.keyVault
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
  }
}

module grantVaultAdministratorAccess '../../_azure/identity/role-assignment.bicep' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: 'grant-vaultadmin-${uniqueString(id.principalId)}'
  params: {
    principalId: id.principalId
    principalType: id.principalType
    roleId: vaultAdministratorRoleId
  }
}]

module grantSecretsUserAccess '../../_azure/identity/role-assignment.bicep' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: 'grant-secretsuser-${uniqueString(id.principalId)}'
  params: {
    principalId: id.principalId
    principalType: id.principalType
    roleId: vaultSecretsUserRoleId
  }
}]

module appConfigurationPrivateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (deploymentSettings.isNetworkIsolated && networkIsolationSettings != null) {
  name: 'app-configuration-private-endpoint'
  scope: resourceGroup(networkIsolationSettings != null ? networkIsolationSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: resourceNames.appConfigurationPrivateEndpoint
    location: location
    tags: tags

    // Dependencies
    linkServiceName: appConfiguration.outputs.name
    linkServiceId: appConfiguration.outputs.id
    subnetResourceId: subnetId

    // Settings
    dnsZoneName: 'privatelink.azconfig.io'
    groupIds: [ 'configurationStores' ]
  }
}

module keyVaultPrivateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (deploymentSettings.isNetworkIsolated && networkIsolationSettings != null) {
  name: 'key-vault-private-endpoint'
  scope: resourceGroup(networkIsolationSettings != null ? networkIsolationSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: resourceNames.keyVaultPrivateEndpoint
    location: location
    tags: tags

    // Dependencies
    linkServiceName: keyVault.outputs.name
    linkServiceId: keyVault.outputs.id
    subnetResourceId: subnetId

    // Settings
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupIds: [ 'vault' ]
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output app_configuration_name string = appConfiguration.outputs.name
output app_configuration_uri string = appConfiguration.outputs.uri

output key_vault_name string = keyVault.outputs.name
output key_vault_uri string = keyVault.outputs.uri
