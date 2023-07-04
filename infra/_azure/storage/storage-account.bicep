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
param userIdentities ApplicationIdentity[] = []

@allowed([ 'Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS'])
@description('The pricing tier for the resource; note that Standard is required for network isolation.')
param sku string = 'Standard_LRS'

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [

] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'StorageBlobLogs'
  'StorageFileLogs'
  'StorageQueueLogs'
  'StorageTableLogs'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

@description('Built in \'Storage Account Contributer\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var storageOwnerRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'

@description('Built in \'Reader and Data Access\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var storageUserRoleId = 'c12c1c16-33a1-487b-954d-41c89c60f349'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    accessTier: 'Hot'
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  }
}

resource grantOwnerAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: guid(storageOwnerRoleId, id.principalId, storageAccount.id, resourceGroup().name)
  scope: storageAccount
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageOwnerRoleId)
    principalId: id.principalId
  }
}]

resource grantUserAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in userIdentities: if (!empty(id.principalId)) {
  name: guid(storageUserRoleId, id.principalId, storageAccount.id, resourceGroup().name)
  scope: storageAccount
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageUserRoleId)
    principalId: id.principalId
  }
}]

module privateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-privateEndpoint'
  scope: resourceGroup(privateEndpointSettings!.resourceGroupName)
  params: {
    name: privateEndpointSettings!.name
    location: location
    tags: tags

    // Dependencies
    linkServiceName: storageAccount.name
    linkServiceId: storageAccount.id
    subnetResourceId: privateEndpointSettings!.subnetId

    // Settings
    dnsZoneName: 'privatelink.azconfig.io'
    groupIds: [ 'configurationStores' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: storageAccount
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

output id string = storageAccount.id
output name string = storageAccount.name
