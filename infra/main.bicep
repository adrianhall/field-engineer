targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Infrastructure description
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

/*
** Parameters that are provided by Azure Developer CLI.
**
** If you are running this with bicep, use the main.parameters.json
** and overrides to generate these.
*/

@minLength(3)
@maxLength(18)
@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@minLength(3)
@description('The email address of the owner of the workload.')
param ownerEmail string

@minLength(3)
@description('The name of the owner of the workload.')
param ownerName string

@description('The ID of the running user or service principal.  This will be set as the owner when needed.')
param principalId string = ''

@allowed([ 'ServicePrincipal', 'User' ])
@description('The type of the principal specified in \'principalId\'')
param principalType string = 'ServicePrincipal'

/*
** Passwords - specify these!
*/
@secure()
@minLength(8)
@description('The password for the administrator account.  This will be used for the jump host, SQL server, and anywhere else a password is needed for creating a resource.')
param administratorPassword string = newGuid()

@minLength(8)
@description('The username for the administrator account.  This will be used for the jump host, SQL server, and anywhere else a password is needed for creating a resource.')
param administratorUsername string = 'azureadmin'

/*
** Parameters that make changes to the deployment based on requirements.  They mostly have
** "reasonable" defaults such that a developer can just run "azd up" and get a working dev
** system.
*/

// Settings for setting up a build agent for Azure DevOps
@description('The URL of the Azure DevOps organization.  If this and the adoToken is provided, then an Azure DevOps build agent will be deployed.')
param adoOrganizationUrl string = ''

@description('The access token for the Azure DevOps organization.  If this and the adoOrganizationUrl is provided, then an Azure DevOps build agent will be deployed.')
param adoToken string = ''

// Settings for setting up a build agent for GitHub Actions
@description('The URL of the GitHub repository.  If this and the githubToken is provided, then a GitHub Actions build agent will be deployed.')
param githubRepositoryUrl string = ''

@description('The personal access token for the GitHub repository.  If this and the githubRepositoryUrl is provided, then a GitHub Actions build agent will be deployed.')
param githubToken string = ''

// The IP address for the current system.  This is used to set up the firewall
// for Key Vault and SQL Server if in development mode.
@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string = ''

// A differentiator for the environment.  This is used in CI/CD testing to ensure
// that each environment is unique.
@description('A differentiator for the environment.  Set this to a build number or date to ensure that the resource groups and resources are unique.')
param differentiator string = 'none'

// Environment type - dev or prod; affects sizing and what else is deployed alongside.
@allowed([ 'dev', 'prod' ])
@description('The set of pricing SKUs to choose for resources.  \'dev\' uses cheaper SKUs by avoiding features that are unnecessary for writing code.')
param environmentType string = 'dev'

// Deploy Hub Resources; if auto, then
//  - environmentType == dev && networkIsolation == true => true
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy hub resources.  Normally, the hub resources are not deployed since the app developer wouldn\'t have access, but we also need to be able to deploy a complete solution')
param deployHubNetwork string = 'auto'

// Network isolation - determines if the app is deployed in a VNET or not.
//  if environmentType == prod => true
//  if environmentType == dev => false
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy the application in network isolation mode.  \'auto\' will deploy in isolation only if deploying to production.')
param networkIsolation string = 'auto'

// Common App Service Plan - determines if a common app service plan should be deployed.
//  auto = yes in dev, no in prod.
@allowed([ 'auto', 'false', 'true' ])
@description('Should we deploy a common app service plan, used by both the API and WEB app services?  \'auto\' will deploy a common app service plan in dev, but separate plans in prod.')
param useCommonAppServicePlan string = 'auto'

// ========================================================================
// VARIABLES
// ========================================================================

var prefix = '${environmentName}-${environmentType}'

// Boolean to indicate the various values for the deployment settings
var isProduction = environmentType == 'prod'
var isNetworkIsolated = networkIsolation == 'true' || (networkIsolation == 'auto' && isProduction)
var willDeployHubNetwork = isNetworkIsolated && (deployHubNetwork == 'true' || (deployHubNetwork == 'auto' && !isProduction))
var willDeployCommonAppServicePlan = useCommonAppServicePlan == 'true' || (useCommonAppServicePlan == 'auto' && !isProduction)

var deploymentSettings = {
  isProduction: isProduction
  isNetworkIsolated: isNetworkIsolated
  location: location
  name: environmentName
  principalId: principalId
  principalType: principalType
  stage: environmentType
  tags: {
    'azd-env-name': environmentName
    'azd-env-type': environmentType
    'azd-owner-email': ownerEmail
    'azd-owner-name': ownerName
  }
  workloadTags: {
    WorkloadName: environmentName
    Environment: environmentType
    OwnerName: ownerEmail
    ServiceClass: isProduction ? 'Silver' : 'Dev'
    OpsCommitment: 'Workload operations'
  }
}

var diagnosticSettings = {
  logRetentionInDays: isProduction ? 30 : 3
  metricRetentionInDays: isProduction ? 7 : 3
  enableLogs: true
  enableMetrics: true
}

var installBuildAgent = isNetworkIsolated && ((!empty(adoOrganizationUrl) && !empty(adoToken)) || (!empty(githubRepositoryUrl) && !empty(githubToken)))

// ========================================================================
// BICEP MODULES
// ========================================================================

/*
** Every single resource can have a naming override.  Overrides should be placed
** into the 'naming.overrides.jsonc' file.  The output of this module drives the
** naming of all resources.
*/
module naming './modules/naming.bicep' = {
  name: '${prefix}-naming'
  params: {
    deploymentSettings: deploymentSettings
    differentiator: differentiator != 'none' ? differentiator : ''
    overrides: loadJsonContent('./naming.overrides.jsonc')
  }
}

/*
** Resources are organized into one of four resource groups:
**
**  hubResourceGroup      - contains the hub network resources
**  spokeResourceGroup    - contains the spoke network resources
**  sqlResourceGroup      - contains the SQL resources
**  workloadResourceGroup - contains the workload resources 
** 
** Not all of the resource groups are necessarily available - it
** depends on the settings.
*/
module resourceGroups './modules/resource-groups.bicep' = {
  name: '${prefix}-resource-groups'
  params: {
    deploymentSettings: deploymentSettings
    resourceNames: naming.outputs.resourceNames

    // Settings
    deployHubNetwork: willDeployHubNetwork
  }
}

/*
** Azure Monitor Resources
**
** Azure Monitor resources (Log Analytics Workspace and Application Insights) are
** homed in the hub network when it's available, and the workload resource group
** when it's not available.
*/
module azureMonitor './modules/azure-monitor.bicep' = {
  name: '${prefix}-azure-monitor'
  params: {
    deploymentSettings: deploymentSettings
    resourceNames: naming.outputs.resourceNames
    resourceGroupName: willDeployHubNetwork ? naming.outputs.resourceNames.hubResourceGroup : naming.outputs.resourceNames.resourceGroup
  }
  dependsOn: [
    resourceGroups
  ]
}

/*
** Create the hub network, if requested. 
**
** The hub network consists of the following resources
**
**  The hub virtual network with subnets for Bastion Hosts and Firewall
**  The bastion host
**  The firewall
**  A route table that is used within the spoke to reach the firewall
**
** We also set up a budget with cost alerting for the hub network (separate
** from the workload budget)
*/
module hubNetwork './modules/hub-network.bicep' = if (willDeployHubNetwork) {
  name: '${prefix}-hub-network'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    enableBastionHost: true
    enableDDoSProtection: deploymentSettings.isProduction
    enableFirewall: true
    enableJumpHost: true
    enableKeyVault: true
  }
  dependsOn: [
    resourceGroups
  ]
}

/*
** The hub network MAY have created an Azure Monitor workspace.  If it did, we don't need
** to do it again.  If not, we'll create one in the workload resource group
*/


/*
** The spoke network is the network that the workload resources are deployed into.
*/
module spokeNetwork './modules/spoke-network.bicep' = if (isNetworkIsolated) {
  name: '${prefix}-spoke-network'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    routeTableId: willDeployHubNetwork ? hubNetwork.outputs.route_table_id : ''

    // Settings
    createDevopsSubnet: installBuildAgent
  }
  dependsOn: [
    resourceGroups
  ]
}

/*
** Now that the networking resources have been created, we need to peer the networks.  This is
** only done if the hub network was created in this deployment.  If the hub network was not
** deployed, then a manual peering process needs to be done.
*/
module peerVirtualNetworks './modules/peer-networks.bicep' = if (willDeployHubNetwork && isNetworkIsolated) {
  name: '${prefix}-peer-networks'
  params: {
    hubNetwork: {
      name: willDeployHubNetwork ? hubNetwork.outputs.virtual_network_name : ''
      resourceGroupName: naming.outputs.resourceNames.hubResourceGroup
    }
    spokeNetwork: {
      name: isNetworkIsolated ? spokeNetwork.outputs.virtual_network_name : ''
      resourceGroupName: naming.outputs.resourceNames.spokeResourceGroup
    }
  }
}

/*
** Create the application resources.
*/
module workload './modules/workload-resources.bicep' = {
  name: '${prefix}-workload'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    applicationInsightsId: azureMonitor.outputs.application_insights_id
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    subnets: isNetworkIsolated ? spokeNetwork.outputs.subnets : {}

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    clientIpAddress: clientIpAddress
    useCommonAppServicePlan: willDeployCommonAppServicePlan
  }
  dependsOn: [
    resourceGroups
    spokeNetwork
  ]
}

/*
** Create a build agent (only if network isolated and the relevant information has been provided)
*/
module buildAgent './modules/build-agent.bicep' = if (installBuildAgent) {
  name: '${prefix}-build-agent'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    managedIdentityId: workload.outputs.owner_managed_identity_id
    subnets: isNetworkIsolated ? spokeNetwork.outputs.subnets : {}

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    adoOrganizationUrl: adoOrganizationUrl
    adoToken: adoToken
    githubRepositoryUrl: githubRepositoryUrl
    githubToken: githubToken
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

// Hub resources
output bastion_hostname string = willDeployHubNetwork ? hubNetwork.outputs.bastion_hostname : ''
output firewall_hostname string = willDeployHubNetwork ? hubNetwork.outputs.firewall_hostname : ''

// Spoke resources
output build_agent string = installBuildAgent ? buildAgent.outputs.build_agent_hostname : ''

// Workload resources
output service_web_endpoints string[] = workload.outputs.service_web_endpoints
