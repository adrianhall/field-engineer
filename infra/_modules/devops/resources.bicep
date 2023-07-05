targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Devops Resources
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
@description('The subnet ID for the devops subnet, or \'\' if not using a virtual network')
param devopsSubnetId string = ''

@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

@description('The name of the owner managed identity.')
param managedIdentityName string

@description('The subnet ID for the storage subnet, or \'\' if not using a virtual network')
param storageSubnetId string = ''

// ========================================================================
// VARIABLES
// ========================================================================

var moduleTags = union(deploymentSettings.tags, { 'azd-module': 'spoke', 'azd-function': 'devops' })

var devopsContainerImage = {
  name: resourceNames.devopsContainer
  properties: {
    image: 'mcr.microsoft.com/azure-cli:latest'
    ports: [
      { port: 22, protocol: 'TCP' } // SSH
    ]
  }
}

var containers = [ devopsContainerImage ]

// ========================================================================
// AZURE MODULES
// ========================================================================

/*
** You need to decide where to put your DevOps resources.  It may be your
** workload resource group, spoke networking group, or another resource
** group entirely.  We've chosen to put them in the networking resource
** group.
*/
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.spokeResourceGroup
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
  scope: az.resourceGroup(resourceNames.resourceGroup)
}

/*
** The devops resources consists of:
**
**  A storage account with a file share
**  An Azure Container Instance (ACI) container group with:
**    - a Linux container running the Azure CLI.
**
**  In addition, you can provide the following resources:
**    - An Azure DevOps Build Agent
**    - A GitHub Actions Runner
**
** You can use the same container group for the build agents.
*/
module storageAccount '../../_azure/storage/storage-account.bicep' = {
  name: 'devops-storage'
  scope: resourceGroup
  params: {
    name: resourceNames.devopsStorageAccount
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: true // Explicitly true for devops access
    ownerIdentities: [
      { principalId: deploymentSettings.principalId,         principalType: deploymentSettings.principalType }
      { principalId: managedIdentity.properties.principalId, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      name: resourceNames.devopsStorageAccountPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: storageSubnetId
    } : null
  }
}

module fileShare '../../_azure/storage/file-share.bicep' = {
  name: 'devops-file-share'
  scope: resourceGroup
  params: {
    name: resourceNames.devopsFileShare
    storageAccountName: storageAccount.outputs.name
  }
}

module containerGroup '../../_azure/hosting/container-group.bicep' = {
  name: 'devops-container-group'
  scope: resourceGroup
  params: {
    name: resourceNames.devopsContainerGroup
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    managedIdentityName: managedIdentityName
    subnetResourceId: devopsSubnetId

    // Settings
    containers: containers
  }
}

