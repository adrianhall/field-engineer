targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resource Deployment - Configuration Resources
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

/*
** From: infra/_types/DeploymentSettings.bicep
*/
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', we are deploying hub network resources.')
  deployHubNetwork: bool

  @description('If \'true\', we are deploying a jump host.')
  deployJumphost: bool

  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', all resources should be secured with a virtual network.')
  isNetworkIsolated: bool

  @description('If \'true\', the jump host should have a public IP address.')
  jumphostIsPublic: bool

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The common tags that should be used for all created resources')
  tags: object
  
  @description('If \'true\', use a common app service plan for workload app services.')
  useCommonAppServicePlan: bool
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
** From infra/_types/NetworkIsolationSettings.bicep
*/
@description('A type describing the network isolation settings for a module.')
type NetworkIsolationSettings = {
  @description('The name of the private endpoint subnet, for inbound traffic')
  inboundSubnetName: string

  @description('The name of the VNET integration subnet, for outbound traffic')
  outboundSubnetName: string

  @description('The name of the virtual network holding the subnets')
  virtualNetworkName: string

  @description('The resource group holding the virtual network')
  resourceGroupName: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The global diagnostic settings')
param diagnosticSettings DiagnosticSettings

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The list of resource names to use')
param resourceNames object

@description('The list of tags to configure on each created resource.')
param tags object

/*
** Dependencies
*/
@description('The Key Vault to write the SQL Administrator information to')
param keyVaultName string = ''

@description('The ID of the Log Analytics Workspace to send audit and diagnostic data to.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@description('The network isolation settings to use for this service.')
param networkIsolationSettings NetworkIsolationSettings?

@description('The name of the managed identity to set as owner of the resource')
param ownerManagedIdentityName string

@secure()
@minLength(8)
@description('The password for the SQL Administrator; used if creating the server')
param sqlAdministratorPassword string

@minLength(8)
@description('The username for the SQL Administrator; used if creating the server')
param sqlAdministratorUsername string

// ========================================================================
// VARIABLES
// ========================================================================

var createSqlServer = resourceNames.sqlResourceGroup == resourceNames.resourceGroup

var subnetId = deploymentSettings.isNetworkIsolated && networkIsolationSettings != null ? resourceId(networkIsolationSettings!.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', networkIsolationSettings!.virtualNetworkName, networkIsolationSettings!.inboundSubnetName ?? '') : ''

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource existing_sqlserver 'Microsoft.Sql/servers@2021-11-01' existing = if (!createSqlServer) {
  name: resourceNames.sqlServer
  scope: resourceGroup(resourceNames.sqlResourceGroup)
}

// ========================================================================
// AZURE MODULES
// ========================================================================

module created_sqlserver '../../_azure/database/sql-server.bicep' = if (createSqlServer) {
  name: 'workload-sqlserver'
  scope: resourceGroup(resourceNames.sqlResourceGroup)
  params: {
    name: resourceNames.sqlServer
    location: location
    tags: tags

    // Dependencies
    administratorManagedIdentityName: ownerManagedIdentityName

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

module sqlDatabase '../../_azure/database/sql-database.bicep' = {
  name: 'workload-sqldatabase'
  scope: resourceGroup(resourceNames.sqlResourceGroup)
  params: {
    name: resourceNames.sqlDatabase
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sqlServerName: createSqlServer ? created_sqlserver.outputs.name : existing_sqlserver.name

    // Settings
    diagnosticSettings: diagnosticSettings
    dtuCapacity: deploymentSettings.isProduction ? 125 : 10
    sku: deploymentSettings.isProduction ? 'Premium' : 'Standard'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module writeSqlAdminInfo '../../_azure/security/key-vault-secrets.bicep' = if (createSqlServer && !empty(keyVaultName)) {
  name: 'write-sql-admin-info-to-keyvault'
  params: {
    name: keyVaultName
    secrets: [
      { key: 'FieldEngineer--SqlAdministratorUsername', value: sqlAdministratorUsername }
      { key: 'FieldEngineer--SqlAdministratorPassword', value: sqlAdministratorPassword }
      { key: 'FieldEngineer--SqlConnectionString', value: 'Server=tcp:${created_sqlserver.outputs.hostname},1433;Database=${sqlDatabase.name};User ID=${sqlAdministratorUsername};Password=${sqlAdministratorPassword};Trusted_Connection=False;Encrypt=True;' }
    ]
  }
}

module sqlDatabasePrivateEndpoint '../../_azure/networking/private-endpoint.bicep' = if (deploymentSettings.isNetworkIsolated && networkIsolationSettings != null) {
  name: 'private-endpoint-for-sqldb'
  scope: resourceGroup(networkIsolationSettings != null ? networkIsolationSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: resourceNames.sqlDatabasePrivateEndpoint
    location: location
    tags: tags

    // Dependencies
    linkServiceName: '${sqlDatabase.outputs.sql_server_name}/${sqlDatabase.outputs.name}'
    linkServiceId: sqlDatabase.outputs.sql_server_id
    subnetResourceId: subnetId

    // Settings:
    dnsZoneName: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    groupIds: [ 'sqlServer' ]
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output sql_connection_string string = sqlDatabase.outputs.connection_string
output sql_database_name string = sqlDatabase.outputs.name
output sql_server_name string = sqlDatabase.outputs.sql_server_name
