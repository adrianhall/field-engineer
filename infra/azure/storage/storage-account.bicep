// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

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
@description('The name of the user-defined managed identity that can access this storage account')
param managedIdentityName string

@description('The ID of the current user, used to provide developer access to the resource')
param principalId string = ''

/*
** Service settings
*/
@allowed([ 'Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS' ])
@description('The pricing SKU to use')
param sku string = 'Standard_LRS'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var dataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

resource grantDataOwnerToCurrentUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(dataOwnerRoleId, principalId, name)
  properties: {
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', dataOwnerRoleId)
    principalId: principalId
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', diagnosticSettings.logAnalyticsWorkspaceName)
    logs: []
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
