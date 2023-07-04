targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Resource Naming
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

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The overrides for the naming scheme.  Load this from the naming.overrides.jsonc file.')
param overrides object = {}

/*
** This is a unique token that will be used as a differentiator for all resources.
*/
var resourceToken = uniqueString(subscription().id, deploymentSettings.name, deploymentSettings.location, deploymentSettings.stage)

/*
** This is the split-out common prefix for resource groups.
*/
var resourceGroupPrefix = 'rg-${deploymentSettings.name}-${deploymentSettings.stage}-${deploymentSettings.location}'

/*
** This is the list of resource names that are used in the application.  For the list of
** Cloud Adoption Framework abbreviations, see the following page:
**
** https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
*/
var defaultResourceNames = {
    /*
    ** Hub Networking Resources
    */
    hubResourceGroup: '${resourceGroupPrefix}-hub'
    hubBastionPublicIpAddress: 'pip-bas-${resourceToken}'
    hubBastionSubnet: 'AzureBastionSubnet'
    hubBastion: 'bas-${resourceToken}'
    hubFirewallPublicIpAddress: 'pip-afw-${resourceToken}'
    hubFirewallSubnet: 'AzureFirewallSubnet'
    hubFirewall: 'afw-${resourceToken}'
    hubRouteTable: 'rt-${resourceToken}'
    hubVirtualNetwork: 'vnet-hub-${resourceToken}'

    /*
    ** Spoke Networking Resources
    */
    blockInboundNetworkSecurityGroup: 'nsg-block-inbound-${resourceToken}'
    configurationNetworkSecurityGroup: 'nsg-configuration-${resourceToken}'
    inboundHttpNetworkSecurityGroup: 'nsg-inbound-http-${resourceToken}'
    spokeApiInboundSubnet: 'ApiInboundSubnet'
    spokeApiOutboundSubnet: 'ApiOutboundSubnet'
    spokeBuildAgentSubnet: 'BuildAgentSubnet'
    spokeConfigurationSubnet: 'ConfigurationSubnet'
    spokeDevopsSubnet: 'DevopsSubnet'
    spokeJumphostSubnet: 'JumphostSubnet'
    spokeStorageSubnet: 'StorageSubnet'
    spokeWebInboundSubnet: 'WebInboundSubnet'
    spokeWebOutboundSubnet: 'WebOutboundSubnet'
    spokeResourceGroup: '${resourceGroupPrefix}-spoke'
    spokeVirtualNetwork: 'vnet-spoke-${resourceToken}'
    storageNetworkSecurityGroup: 'nsg-storage-${resourceToken}'

    /*
    ** Shared Monitoring Resources
    */
    applicationInsights: 'appi-${resourceToken}'
    applicationInsightsDashboard: 'dash-${resourceToken}'
    budget: 'budget-${deploymentSettings.name}-${deploymentSettings.stage}'
    logAnalyticsWorkspace: 'log-${resourceToken}'

    /*
    ** Workload Specific Resources
    */
    apiAppService: 'app-api-${resourceToken}'
    apiAppServicePlan: 'asp-api-${resourceToken}'
    apiManagedIdentity: 'id-api-${resourceToken}'
    apiPrivateEndpoint: 'pe-api-${resourceToken}'
    appConfiguration: 'appcs-${resourceToken}'
    appConfigurationPrivateEndpoint: 'pe-appcs-${resourceToken}'
    commonAppServicePlan: 'asp-common-${resourceToken}'
    frontDoorEndpoint: 'fde-${resourceToken}'
    frontDoorProfile: 'afd-${resourceToken}'
    keyVault: 'kv-${resourceToken}'
    keyVaultPrivateEndpoint: 'pe-kv-${resourceToken}'
    ownerManagedIdentity: 'id-owner-${resourceToken}'
    resourceGroup: '${resourceGroupPrefix}-workload'
    sqlDatabase: 'fieldengineer-${resourceToken}'
    sqlDatabasePrivateEndpoint: 'pe-sqldb-${resourceToken}'
    sqlServer: 'sql-${resourceToken}'
    sqlResourceGroup: '${resourceGroupPrefix}-workload'
    webAppService: 'app-web-${resourceToken}'
    webAppServicePlan: 'asp-web-${resourceToken}'
    webApplicationFirewall: 'waf${resourceToken}'
    webManagedIdentity: 'id-web-${resourceToken}'
    webPrivateEndpoint: 'pe-web-${resourceToken}'

    /*
    ** Administrative Resources - jumphost, Build Agents, etc.
    */
    buildAgent: 'vm-build-${resourceToken}'
    buildAgentPublicIpAddress: 'pip-build-${resourceToken}'
    devopsContainerGroup: 'ci-devops-${resourceToken}'
    devopsContainer: 'devops-container-${resourceToken}'
    devopsFileShare: 'share-devops-${resourceToken}'
    devopsStoragePrivateEndpoint: 'pe-stdevops-${resourceToken}'
    devopsStorageAccount: 'stdevops${resourceToken}'
    jumphost: 'vm-jump-${resourceToken}'
    jumphostPublicIpAddress: 'pip-jump-${resourceToken}'

    /*
    ** Usernames
    */
    administratorUsername: 'appadmin'
}

// ========================================================================
// OUTPUTS
// ========================================================================

output resourceToken string = resourceToken

output resourceNames object = {
    /*
    ** Hub Networking Resources
    */
    hubResourceGroup: contains(overrides, 'hubResourceGroup') && !empty(overrides.hubResourceGroup) ? overrides.hubResourceGroup : defaultResourceNames.hubResourceGroup
    hubBastionPublicIpAddress: contains(overrides, 'hubBastionPublicIpAddress') && !empty(overrides.hubBastionPublicIpAddress) ? overrides.hubBastionPublicIpAddress : defaultResourceNames.hubBastionPublicIpAddress
    hubBastionSubnet: contains(overrides, 'hubBastionSubnet') && !empty(overrides.hubBastionSubnet) ? overrides.hubBastionSubnet : defaultResourceNames.hubBastionSubnet
    hubBastion: contains(overrides, 'hubBastion') && !empty(overrides.hubBastion) ? overrides.hubBastion : defaultResourceNames.hubBastion
    hubFirewallPublicIpAddress: contains(overrides, 'hubFirewallPublicIpAddress') && !empty(overrides.hubFirewallPublicIpAddress) ? overrides.hubFirewallPublicIpAddress : defaultResourceNames.hubFirewallPublicIpAddress
    hubFirewallSubnet: contains(overrides, 'hubFirewallSubnet') && !empty(overrides.hubFirewallSubnet) ? overrides.hubFirewallSubnet : defaultResourceNames.hubFirewallSubnet
    hubFirewall: contains(overrides, 'hubFirewall') && !empty(overrides.hubFirewall) ? overrides.hubFirewall : defaultResourceNames.hubFirewall
    hubRouteTable: contains(overrides, 'hubRouteTable') && !empty(overrides.hubRouteTable) ? overrides.hubRouteTable : defaultResourceNames.hubRouteTable
    hubVirtualNetwork: contains(overrides, 'hubVirtualNetwork') && !empty(overrides.hubVirtualNetwork) ? overrides.hubVirtualNetwork : defaultResourceNames.hubVirtualNetwork

    /*
    ** Spoke Networking Resources
    */
    blockInboundNetworkSecurityGroup: contains(overrides, 'blockInboundNetworkSecurityGroup') && !empty(overrides.blockInboundNetworkSecurityGroup) ? overrides.blockInboundNetworkSecurityGroup : defaultResourceNames.blockInboundNetworkSecurityGroup
    configurationNetworkSecurityGroup: contains(overrides, 'configurationNetworkSecurityGroup') && !empty(overrides.configurationNetworkSecurityGroup) ? overrides.configurationNetworkSecurityGroup : defaultResourceNames.configurationNetworkSecurityGroup
    inboundHttpNetworkSecurityGroup: contains(overrides, 'inboundHttpNetworkSecurityGroup') && !empty(overrides.inboundHttpNetworkSecurityGroup) ? overrides.inboundHttpNetworkSecurityGroup : defaultResourceNames.inboundHttpNetworkSecurityGroup
    spokeApiInboundSubnet: contains(overrides, 'spokeApiInboundSubnet') && !empty(overrides.spokeApiInboundSubnet) ? overrides.spokeApiInboundSubnet : defaultResourceNames.spokeApiInboundSubnet
    spokeApiOutboundSubnet: contains(overrides, 'spokeApiOutboundSubnet') && !empty(overrides.spokeApiOutboundSubnet) ? overrides.spokeApiOutboundSubnet : defaultResourceNames.spokeApiOutboundSubnet
    spokeBuildAgentSubnet: contains(overrides, 'spokeBuildAgentSubnet') && !empty(overrides.spokeBuildAgentSubnet) ? overrides.spokeBuildAgentSubnet : defaultResourceNames.spokeBuildAgentSubnet
    spokeConfigurationSubnet: contains(overrides, 'spokeConfigurationSubnet') && !empty(overrides.spokeConfigurationSubnet) ? overrides.spokeConfigurationSubnet : defaultResourceNames.spokeConfigurationSubnet
    spokeDevopsSubnet: contains(overrides, 'spokeDevopsSubnet') && !empty(overrides.spokeDevopsSubnet) ? overrides.spokeDevopsSubnet : defaultResourceNames.spokeDevopsSubnet
    spokeJumphostSubnet: contains(overrides, 'spokejumphostSubnet') && !empty(overrides.spokeJumphostSubnet) ? overrides.spokeJumphostSubnet : defaultResourceNames.spokeJumphostSubnet
    spokeStorageSubnet: contains(overrides, 'spokeStorageSubnet') && !empty(overrides.spokeStorageSubnet) ? overrides.spokeStorageSubnet : defaultResourceNames.spokeStorageSubnet
    spokeWebInboundSubnet: contains(overrides, 'spokeWebInboundSubnet') && !empty(overrides.spokeWebInboundSubnet) ? overrides.spokeWebInboundSubnet : defaultResourceNames.spokeWebInboundSubnet
    spokeWebOutboundSubnet: contains(overrides, 'spokeWebOutboundSubnet') && !empty(overrides.spokeWebOutboundSubnet) ? overrides.spokeWebOutboundSubnet : defaultResourceNames.spokeWebOutboundSubnet
    spokeResourceGroup: contains(overrides, 'spokeResourceGroup') && !empty(overrides.spokeResourceGroup) ? overrides.spokeResourceGroup : defaultResourceNames.spokeResourceGroup
    spokeVirtualNetwork: contains(overrides, 'spokeVirtualNetwork') && !empty(overrides.spokeVirtualNetwork) ? overrides.spokeVirtualNetwork : defaultResourceNames.spokeVirtualNetwork
    storageNetworkSecurityGroup: contains(overrides, 'storageNetworkSecurityGroup') && !empty(overrides.storageNetworkSecurityGroup) ? overrides.storageNetworkSecurityGroup : defaultResourceNames.storageNetworkSecurityGroup

    /*
    ** Shared Monitoring Resources
    */
    applicationInsights: contains(overrides, 'applicationInsights') && !empty(overrides.applicationInsights) ? overrides.applicationInsights : defaultResourceNames.applicationInsights
    applicationInsightsDashboard: contains(overrides, 'applicationInsightsDashboard') && !empty(overrides.applicationInsightsDashboard) ? overrides.applicationInsightsDashboard : defaultResourceNames.applicationInsightsDashboard
    budget: contains(overrides, 'budget') && !empty(overrides.budget) ? overrides.budget : defaultResourceNames.budget
    logAnalyticsWorkspace: contains(overrides, 'logAnalyticsWorkspace') && !empty(overrides.logAnalyticsWorkspace) ? overrides.logAnalyticsWorkspace : defaultResourceNames.logAnalyticsWorkspace

    /*
    ** Workload Specific Resources
    */
    apiAppService: contains(overrides, 'apiAppService') && !empty(overrides.apiAppService) ? overrides.apiAppService : defaultResourceNames.apiAppService
    apiAppServicePlan: contains(overrides, 'apiAppServicePlan') && !empty(overrides.apiAppServicePlan) ? overrides.apiAppServicePlan : defaultResourceNames.apiAppServicePlan
    apiManagedIdentity: contains(overrides, 'apiManagedIdentity') && !empty(overrides.apiManagedIdentity) ? overrides.apiManagedIdentity : defaultResourceNames.apiManagedIdentity
    apiPrivateEndpoint: contains(overrides, 'apiPrivateEndpoint') && !empty(overrides.apiPrivateEndpoint) ? overrides.apiPrivateEndpoint : defaultResourceNames.apiPrivateEndpoint
    appConfiguration: contains(overrides, 'appConfiguration') && !empty(overrides.appConfiguration) ? overrides.appConfiguration : defaultResourceNames.appConfiguration
    appConfigurationPrivateEndpoint: contains(overrides, 'appConfigurationPrivateEndpoint') && !empty(overrides.appConfigurationPrivateEndpoint) ? overrides.appConfigurationPrivateEndpoint : defaultResourceNames.appConfigurationPrivateEndpoint
    commonAppServicePlan: contains(overrides, 'commonAppServicePlan') && !empty(overrides.commonAppServicePlan) ? overrides.commonAppServicePlan : defaultResourceNames.commonAppServicePlan
    frontDoorEndpoint: contains(overrides, 'frontDoorEndpoint') && !empty(overrides.frontDoorEndpoint) ? overrides.frontDoorEndpoint : defaultResourceNames.frontDoorEndpoint
    frontDoorProfile: contains(overrides, 'frontDoorProfile') && !empty(overrides.frontDoorProfile) ? overrides.frontDoorProfile : defaultResourceNames.frontDoorProfile
    keyVault: contains(overrides, 'keyVault') && !empty(overrides.keyVault) ? overrides.keyVault : defaultResourceNames.keyVault
    keyVaultPrivateEndpoint: contains(overrides, 'keyVaultPrivateEndpoint') && !empty(overrides.keyVaultPrivateEndpoint) ? overrides.keyVaultPrivateEndpoint : defaultResourceNames.keyVaultPrivateEndpoint
    ownerManagedIdentity: contains(overrides, 'ownerManagedIdentity') && !empty(overrides.ownerManagedIdentity) ? overrides.ownerManagedIdentity : defaultResourceNames.ownerManagedIdentity
    resourceGroup: contains(overrides, 'resourceGroup') && !empty(overrides.resourceGroup) ? overrides.resourceGroup : defaultResourceNames.resourceGroup
    sqlDatabase: contains(overrides, 'sqlDatabase') && !empty(overrides.sqlDatabase) ? overrides.sqlDatabase : defaultResourceNames.sqlDatabase
    sqlDatabasePrivateEndpoint: contains(overrides, 'sqlDatabasePrivateEndpoint') && !empty(overrides.sqlDatabasePrivateEndpoint) ? overrides.sqlDatabasePrivateEndpoint : defaultResourceNames.sqlDatabasePrivateEndpoint
    sqlServer: contains(overrides, 'sqlServer') && !empty(overrides.sqlServer) ? overrides.sqlServer : defaultResourceNames.sqlServer
    sqlResourceGroup: contains(overrides, 'sqlResourceGroup') && !empty(overrides.sqlResourceGroup) ? overrides.sqlResourceGroup : defaultResourceNames.sqlResourceGroup
    webAppService: contains(overrides, 'webAppService') && !empty(overrides.webAppService) ? overrides.webAppService : defaultResourceNames.webAppService
    webAppServicePlan: contains(overrides, 'webAppServicePlan') && !empty(overrides.webAppServicePlan) ? overrides.webAppServicePlan : defaultResourceNames.webAppServicePlan
    webApplicationFirewall: contains(overrides, 'webApplicationFirewall') && !empty(overrides.webApplicationFirewall) ? overrides.webApplicationFirewall : defaultResourceNames.webApplicationFirewall
    webManagedIdentity: contains(overrides, 'webManagedIdentity') && !empty(overrides.webManagedIdentity) ? overrides.webManagedIdentity : defaultResourceNames.webManagedIdentity
    webPrivateEndpoint: contains(overrides, 'webPrivateEndpoint') && !empty(overrides.webPrivateEndpoint) ? overrides.webPrivateEndpoint : defaultResourceNames.webPrivateEndpoint

    /*
    ** Administrative Resources - jumphost, Build Agents, etc.
    */
    buildAgent: contains(overrides, 'buildAgent') && !empty(overrides.buildAgent) ? overrides.buildAgent : defaultResourceNames.buildAgent
    buildAgentPublicIpAddress: contains(overrides, 'buildAgentPublicIpAddress') && !empty(overrides.buildAgentPublicIpAddress) ? overrides.buildAgentPublicIpAddress : defaultResourceNames.buildAgentPublicIpAddress
    devopsContainerGroup: contains(overrides, 'devopsContainerGroup') && !empty(overrides.devopsContainerGroup) ? overrides.devopsContainerGroup : defaultResourceNames.devopsContainerGroup
    devopsContainer: contains(overrides, 'devopsContainer') && !empty(overrides.devopsContainer) ? overrides.devopsContainer : defaultResourceNames.devopsContainer
    devopsFileShare: contains(overrides, 'devopsFileShare') && !empty(overrides.devopsFileShare) ? overrides.devopsFileShare : defaultResourceNames.devopsFileShare
    devopsStoragePrivateEndpoint: contains(overrides, 'devopsStoragePrivateEndpoint') && !empty(overrides.devopsStoragePrivateEndpoint) ? overrides.devopsStoragePrivateEndpoint : defaultResourceNames.devopsStoragePrivateEndpoint
    devopsStorageAccount: contains(overrides, 'devopsStorageAccount') && !empty(overrides.devopsStorageAccount) ? overrides.devopsStorageAccount : defaultResourceNames.devopsStorageAccount
    jumphost: contains(overrides, 'jumphost') && !empty(overrides.jumphost) ? overrides.jumphost : defaultResourceNames.jumphost
    jumphostPublicIpAddress: contains(overrides, 'jumphostPublicIpAddress') && !empty(overrides.jumphostPublicIpAddress) ? overrides.jumphostPublicIpAddress : defaultResourceNames.jumphostPublicIpAddress

    /*
    ** Administrator Usernames
    */
    administratorUsername: contains(overrides, 'administratorUsername') && !empty(overrides.administratorUsername) ? overrides.administratorUsername : defaultResourceNames.administratorUsername
}
