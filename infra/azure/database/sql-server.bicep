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
@description('If set, the name of the managed identity to set as the owner of the resource')
param managedIdentityName string = ''

/*
** Service Settings
*/
@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@secure()
@description('The SQL Administrator password.')
param sqlAdministratorPassword string

@description('The SQL Administrator username to use.')
param sqlAdministratorUsername string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorUsername
    administratorLoginPassword: sqlAdministratorPassword
    administrators: {
      login: managedIdentity.name
      principalType: 'User'
      sid: managedIdentity.properties.principalId
      tenantId: managedIdentity.properties.tenantId
    }
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    version: '12.0'
  }

  // Note that we cannot set up the firewall unless publicNetworkAccess is enabled.
  resource allowAzureServices 'firewallRules' = if (enablePublicNetworkAccess) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }

  resource auditSettings 'auditingSettings' = {
    name: 'default'
    properties: {
      state: diagnosticSettings.enableAuditLogs ? 'Enabled' : 'Disabled'
      isAzureMonitorTargetEnabled: true
    }
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = sqlServer.id
output name string = sqlServer.name
