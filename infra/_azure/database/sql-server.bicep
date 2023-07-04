// ========================================================================
//     USER-DEFINED TYPES
// ========================================================================

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

// ========================================================================
//     PARAMETERS
// ========================================================================

@description('The location of the resource')
param location string = resourceGroup().location

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The user-assigned managed identity to configure as an administrator.')
param managedIdentityName string

/*
** Settings
*/
@description('The diagnostic logging settings')
param diagnosticSettings DiagnosticSettings

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@secure()
@minLength(8)
@description('The password for the SQL Administrator; used if creating the server')
param sqlAdministratorPassword string

@minLength(8)
@description('The username for the SQL Administrator; used if creating the server')
param sqlAdministratorUsername string

// ========================================================================
//     AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' =  {
  location: location
  name: name
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorUsername
    administratorLoginPassword: sqlAdministratorPassword
    administrators: {
      // NOTE: This is a workaround because we can only install one administrator right now.
      // Azure SQL method: Create an AAD Group and specify the group here.
      // Our preferred method: Have a custom role that a user can be provided access to.
      azureADOnlyAuthentication: false
      login: managedIdentity.name
      principalType: 'User'
      sid: managedIdentity.properties.principalId
      tenantId: managedIdentity.properties.tenantId
    }
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    version: '12.0'
  }

  resource allowAzureServices 'firewallRules' = if (enablePublicNetworkAccess) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
}

resource auditSettings 'Microsoft.Sql/servers/auditingSettings@2021-11-01' = if (diagnosticSettings.enableAuditLogs) {
  name: 'default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output id string = sqlServer.id
output name string = sqlServer.name

output hostname string = sqlServer.properties.fullyQualifiedDomainName
