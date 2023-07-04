targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Workload Resources
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

  @description('The primary Azure region to host resources')
  location: string

  @description('If \'true\', the jump host should have a public IP address.')
  jumphostIsPublic: bool

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object

  @description('If \'true\', use a common app service plan for workload app services.')
  useCommonAppServicePlan: bool
}

/*
** From: infra/_types/DiagnosticSettings.bicep
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
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The global diagnostic settings')
param diagnosticSettings DiagnosticSettings

@description('The list of resource names to use')
param resourceNames object

/*
** Dependencies
*/
@description('The managed identity to use for communicating with other resources.')
param managedIdentityName string

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The subnet ID for the devops subnet, or \'\' if not using a virtual network')
param devopsSubnetId string = ''

@description('The subnet ID for the storage subnet, or \'\' if not using a virtual network')
param storageSubnetId string = ''

// ========================================================================
// VARIABLES
// ========================================================================

var powerShellImage = 'mcr.microsoft.com/azure-powershell:latest'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: resourceNames.resourceGroup
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
  scope: resourceGroup
}

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: resourceNames.appConfiguration
  scope: resourceGroup
}

module storageAccount '../../_azure/storage/storage-account.bicep' = {
  name: 'devops-storage-account'
  scope: resourceGroup
  params: {
    name: resourceNames.devopsStorageAccount
    location: deploymentSettings.location
    tags: deploymentSettings.tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: true   // Needs to always be true for DevOps functionality
    ownerIdentities: [
      { principalId: deploymentSettings.principalId,         principalType: deploymentSettings.principalType }
      { principalId: managedIdentity.properties.principalId, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.devopsStoragePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: storageSubnetId
    } : null
  }
}

module devopsHost '../../_azure/hosting/container-instance.bicep' = {
  name: 'devops-host'
  scope: resourceGroup
  params: {
    name: resourceNames.devopsContainer
    location: deploymentSettings.location
    tags: deploymentSettings.tags

    // Dependencies
    managedIdentityName: managedIdentityName
    subnetResourceId: devopsSubnetId

    // Settings
    containerGroupName: resourceNames.devopsContainerGroup
    environmentVariables: [
      { name: 'AppConfigurationServiceUri', value: appConfiguration.properties.endpoint }
    ]
    image: powerShellImage
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output devops_container_name string = devopsHost.outputs.container_name
output devops_container_group_name string = devopsHost.outputs.container_group_name
output devops_ip_address string = devopsHost.outputs.container_ip_address
