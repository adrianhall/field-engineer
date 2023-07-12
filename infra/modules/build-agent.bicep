targetScope = 'subscription'

/*
** Create a Build Agent for Devops
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

  @description('The primary Azure region to host resources')
  location: string

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

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// From: infra/types/BuildAgentSettings.bicep
@description('Describes the required settings for a Azure DevOps Pipeline runner')
type AzureDevopsSettings = {
  @description('The URL of the Azure DevOps organization to use for this agent')
  organizationUrl: string

  @description('The Personal Access Token (PAT) to use for the Azure DevOps agent')
  token: string
}

@description('Describes the required settings for a GitHub Actions runner')
type GithubActionsSettings = {
  @description('The URL of the GitHub repository to use for this agent')
  repositoryUrl: string

  @description('The Personal Access Token (PAT) to use for the GitHub Actions runner')
  token: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The ID of the managed identity to use as the identity for communicating with other services.')
param managedIdentityId string

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the build agent.')
param administratorPassword string

@minLength(8)
@description('The username for the administrator account on the build agent.')
param administratorUsername string

@description('If provided, the Azure DevOps settings to use for the build agent.')
param azureDevopsSettings AzureDevopsSettings?

@description('If provided, the GitHub Actions settings to use for the build agent.')
param githubActionsSettings GithubActionsSettings?

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags, {
  WorkloadType: 'Devops'
})

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.spokeResourceGroup
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

module buildAgent '../core/compute/windows-buildagent.bicep' = {
  name: 'devops-build-agent'
  scope: resourceGroup
  params: {
    name: resourceNames.buildAgent
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityId: managedIdentityId
    subnetId: subnets[resourceNames.spokeDevopsSubnet].id

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    azureDevopsSettings: azureDevopsSettings
    diagnosticSettings: diagnosticSettings
    githubActionsSettings: githubActionsSettings
  }
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

output build_agent_id string = buildAgent.outputs.id
output build_agent_name string = buildAgent.outputs.name
output build_agent_hostname string = buildAgent.outputs.computer_name
