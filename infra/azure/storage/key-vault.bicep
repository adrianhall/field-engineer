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
@description('The Principal ID of the managed identity that is allowed to write to the configuration store')
param managedIdentityPrincipalId string = ''

@description('If set, the principal ID of the owner of the resource')
param principalId string = ''

/*
** Service Settings
*/
@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@allowed([ 'standard', 'premium'])
@description('The pricing tier for the resource.')
param sku string = 'standard'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// The RoleId for the Key Vault Administrator role
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

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

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    publicNetworkAccess: enablePublicNetworkAccess ? 'enabled' : 'disabled'
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
  }
}

resource grantKeyVaultAdministratorToCurrentUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(keyVaultAdministratorRoleId, principalId, name)
  properties: {
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: principalId
  }
}

resource grantKeyVaultAdminsitratorToManagedIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentityPrincipalId)) {
  name: guid(keyVaultAdministratorRoleId, managedIdentityPrincipalId, name)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: managedIdentityPrincipalId
  }
}


resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', diagnosticSettings.logAnalyticsWorkspaceName)
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
