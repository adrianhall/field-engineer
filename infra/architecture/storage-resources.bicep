// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type Environment = {
  @description('The name of the Azure Developer environment - user chosen')
  name: string

  @description('If true, we are deploying a production environment.  This is used to size resources appropriately.')
  isProduction: bool

  @description('If true, we want network isolation via a virtual network and private endpoints')
  isNetworkIsolated: bool

  @description('The default region we want the resources to be created in')
  location: string

  @description('The running user/service principal; use a blank string to not use a principalId')
  principalId: string

  @description('A token that is used in generating names for resources.  This is unique to the environment and region')
  resourceToken: string

  @description('A list of default tags to apply to all resources')
  tags: object

  @description('If true, use a common app service plan; if false, create an app service plan per app service')
  useCommonAppServicePlan: bool

  @description('If true, use an existing SQL server; if false, create a new SQL server')
  useExistingSqlServer: bool
}

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

type NetworkIsolationSettings = {
  @description('If set, the name of the inbound private endpoint')
  privateEndpointSubnetName: string?

  @description('If set, the name of the subnet for service connections')
  serviceConnectionSubnetName: string?

  @description('If set, the name of the virtual network to use')
  virtualNetworkName: string?
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The environment we are provisioning for')
param environment Environment

/*
** Resources to potentially create
*/
@description('The name of the SQL Database resource to create')
param sqlDatabaseName string

@description('The name of the SQL Server resource to use or create')
param sqlServerName string

/*
** Dependent resources
*/
@description('The name of the user-defined managed identity to use for the application owner')
param managedIdentityName string

/*
** Service Settings
*/
@secure()
@description('The SQL Administrator password.')
param sqlAdministratorPassword string

@description('The SQL Administrator username to use.')
param sqlAdministratorUsername string

@description('If true, the SQL Server already exists')
param useExistingSqlServer bool = false

@description('The network isolation settings for this architectural component')
param networkIsolationSettings NetworkIsolationSettings = {}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module sqlServer '../azure/database/sql-server.bicep' = if (!useExistingSqlServer) {
  name: 'storage-sqlserver'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: sqlServerName
    tags: environment.tags

    // Dependencies
    managedIdentityName: managedIdentityName

    // Administrator credentials
    enablePublicNetworkAccess: !environment.isNetworkIsolated
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

module sqlDatabase '../azure/database/sql-database.bicep' = {
  name: 'storage-sqldatabase'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: sqlDatabaseName
    tags: environment.tags

    // Dependencies
    sqlServerName: useExistingSqlServer ? sqlServerName : sqlServer.outputs.name

    // Service settings
    dtuCapacity: environment.isProduction ? 125 : 10
    enableZoneRedundancy: environment.isProduction
    sku: environment.isProduction ? 'Premium' : 'Standard'
  }
}

module sqlDatabasePrivateEndpoint '../azure/network/private-endpoint.bicep' = if (contains(networkIsolationSettings, 'privateEndpointSubnetName')) {
  name: 'storage-sqldatabase-private-endpoint'
  params: {
    name: 'private-endpoint-${sqlDatabase.outputs.name}'
    location: environment.location
    tags: environment.tags
    dnsZoneName: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    groupIds: [ 'sqlServer' ]
    linkServiceName: '${sqlServer.outputs.name}/${sqlDatabase.outputs.name}'
    linkServiceId: sqlServer.outputs.id
    subnetName: networkIsolationSettings.privateEndpointSubnetName ?? ''
    virtualNetworkName: networkIsolationSettings.virtualNetworkName ?? ''
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output sql_database_name string = sqlDatabase.outputs.name
output sql_server_name string = useExistingSqlServer ? sqlServerName : sqlServer.outputs.name

output connection_string string = sqlDatabase.outputs.connection_string
