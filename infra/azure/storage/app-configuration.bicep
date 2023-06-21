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

@allowed([ 'Free', 'Standard'])
@description('The pricing tier for the resource; note that Standard is required for network isolation.')
param sku string = 'Standard'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// The RoleId for the App Configuration Data Owner role
var dataOwnerRoleId = '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [
  'Audit'
] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'HttpRequest'
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

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
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

resource grantDataOwnerToManagedIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(managedIdentityPrincipalId)) {
  name: guid(dataOwnerRoleId, managedIdentityPrincipalId, name)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', dataOwnerRoleId)
    principalId: managedIdentityPrincipalId
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: appConfiguration
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

output id string = appConfiguration.id
output name string = appConfiguration.name
output uri string = appConfiguration.properties.endpoint
