// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

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
** From: infra/_types/PrivateEndpointSettings.bicep
*/
@description('The settings for a private endpoint')
type PrivateEndpointSettings = {
  @description('The name of the private endpoint resource')
  name: string

  @description('The name of the resource group to hold the private endpoint')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to')
  subnetId: string
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic logging settings')
param diagnosticSettings DiagnosticSettings

@description('The location of the resource')
param location string = resourceGroup().location

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

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

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'AuditEvent'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'AzurePolicyEvaluationDetails'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

@description('Built in \'Key Vault Administrator\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    publicNetworkAccess: enablePublicNetworkAccess ? 'enabled' : 'disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
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

module privateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: 'key-vault-private-endpoint'
  scope: resourceGroup(privateEndpointSettings!.resourceGroupName)
  params: {
    name: privateEndpointSettings!.name
    location: location
    tags: tags

    // Dependencies
    linkServiceName: keyVault.name
    linkServiceId: keyVault.id
    subnetResourceId: privateEndpointSettings!.subnetId

    // Settings
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupIds: [ 'vault' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: logSettings
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true }
      }
    ]
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = keyVault.id
output name string = keyVault.name
output uri string = keyVault.properties.vaultUri
