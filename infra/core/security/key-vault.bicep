targetScope = 'resourceGroup'

/*
** Key Vault
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a Key Vault resource, including permission grants and diagnostics.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/ApplicationIdentity.bicep
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User')
  principalType: 'ServicePrincipal' | 'User'
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the private endpoint resource.  By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string?

  @description('The name of the resource group to hold the private endpoint.  By default, this uses the same resource group as the resource.')
  resourceGroupName: string?

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('The list of application identities to be granted owner access to the workload resources.')
param ownerIdentities ApplicationIdentity[] = []

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('The list of application identities to be granted reader access to the workload resources.')
param readerIdentities ApplicationIdentity[] = []

// ========================================================================
// VARIABLES
// ========================================================================

@description('Built in \'Key Vault Administrator\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'


var actualPrivateEndpointSettings = union(privateEndpointSettings ?? {}, {
  name: 'pe-${name}'
  resourceGroupName: resourceGroup().name
  subnetId: ''
})

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource grantVaultAdminAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: guid(vaultAdministratorRoleId, id.principalId, keyVault.id, resourceGroup().name)
  scope: keyVault
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vaultAdministratorRoleId)
    principalId: id.principalId
  }
}]

resource grantSecretsUserAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: guid(vaultSecretsUserRoleId, id.principalId, keyVault.id, resourceGroup().name)
  scope: keyVault
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vaultSecretsUserRoleId)
    principalId: id.principalId
  }
}]

module privateEndpoint '../network/private-endpoint.bicep' = if (!empty(actualPrivateEndpointSettings.subnetId)) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(actualPrivateEndpointSettings.resourceGroupName)
  params: {
    name: actualPrivateEndpointSettings.name
    location: location
    tags: tags

    // Dependencies
    linkServiceId: keyVault.id
    linkServiceName: keyVault.name
    subnetId: actualPrivateEndpointSettings.subnetId

    // Settings
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupIds: [ 'vault' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map([ 'AuditEvent', 'AzurePolicyEvaluationDetails' ], (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
      retentionPolicy: { days: diagnosticSettings!.logRetentionInDays, enabled: true }
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
        retentionPolicy: { days: diagnosticSettings!.metricRetentionInDays, enabled: true }
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = keyVault.id
output name string = keyVault.name
