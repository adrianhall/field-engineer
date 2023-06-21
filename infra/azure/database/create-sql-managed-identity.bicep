// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the SQL database')
param name string = 'create-sql-user-script'

@description('The Azure region to create the Log Analytics workspace in')
param location string

@description('The tags to associate with the SQL database')
param tags object

@description('The managed identity that can provision resources and manage the SQL service')
param administratorManagedIdentityName string

@description('The managed identity to add as a SQL user')
param managedIdentityName string

@secure()
@minLength(8)
@description('The administrator password to use when creating the database server')
param sqlAdministratorPassword string

@minLength(8)
@description('The administrator username to use when creating the database server')
param sqlAdministratorUsername string

@description('The SQL database to update')
param sqlDatabaseName string

@description('The SQL server to use for finding the SQL database')
param sqlServerName string

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource administratorManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: administratorManagedIdentityName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' existing = {
  name: sqlDatabaseName
  parent: sqlServer
}

resource createSqlUserScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${administratorManagedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azPowerShellVersion: '9.7'
    retentionInterval: 'PT1H'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    arguments: join([
      '-ServerName \'${sqlServer.name}\''
      '-ResourceGroupName \'${resourceGroup().name}\''
      '-ServerUri \'${sqlServer.properties.fullyQualifiedDomainName}\''
      '-CatalogName \'${sqlDatabase.name}\''
      '-ApplicationId \'${managedIdentity.properties.principalId}\''
      '-ManagedIdentityName \'${managedIdentity.name}\''
      '-SqlAdminUsername \'${sqlAdministratorUsername}\''
      '-SqlAdminPassword \'${sqlAdministratorPassword}\''
    ], ' ')
    scriptContent: loadTextContent('./scripts/create-sql-managed-identity.ps1')
  }
}
