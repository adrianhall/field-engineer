targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Resource Naming
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

/*
** This module provides default names for all the resources used in the
** application. This names can be over-ridden using the naming overrides.
*/

@allowed([ 'dev', 'prod' ])
@description('The stage if the development lifecycle for the workload.')
param environment string = 'dev'

@minLength(3)
@description('The region that the services are to be deployed into.')
param location string

@description('The overrides for the naming scheme.  Load this from the naming.overrides.jsonc file.')
param overrides object = {}

@minLength(3)
@description('The environment name - a unique string that is used to identify THIS deployment.')
param workloadName string

/*
** This is a unique token that will be used as a differentiator for all resources.
*/
var resourceToken = uniqueString(subscription().id, workloadName, location, environment)

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
    hubResourceGroup: 'rg-${workloadName}-${environment}-${location}-hub'
    hubBastionPublicIpAddress: 'pip-bas-${resourceToken}'
    hubBastionSubnet: 'AzureBastionSubnet'
    hubBastion: 'bas-${resourceToken}'
    hubFirewallPublicIpAddress: 'pip-afw-${resourceToken}'
    hubFirewallSubnet: 'AzureFirewallSubnet'
    hubRouteTable: 'rt-${resourceToken}'
    hubVirtualNetwork: 'vnet-hub-${resourceToken}'

    /*
    ** Spoke Networking Resources
    */
    spokeApiInboundSubnet: 'ApiInboundSubnet'
    spokeApiOutboundSubnet: 'ApiOutboundSubnet'
    spokeBuildAgentSubnet: 'BuildAgentSubnet'
    spokeConfigurationSubnet: 'ConfigurationSubnet'
    spokeJumpboxSubnet: 'JumpboxSubnet'
    spokeStorageSubnet: 'StorageSubnet'
    spokeWebInboundSubnet: 'WebInboundSubnet'
    spokeWebOutboundSubnet: 'WebOutboundSubnet'
    spokeResourceGroup: 'rg-${workloadName}-${environment}-${location}-spoke'
    spokeVirtualNetwork: 'vnet-spoke-${resourceToken}'

    /*
    ** Shared Monitoring Resources
    */
    applicationInsights: 'appi-${resourceToken}'
    applicationInsightsDashboard: 'dash-${resourceToken}'
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
    resourceGroup: 'rg-${workloadName}-${environment}-${location}-workload'
    sqlDatabase: 'fieldengineer-${resourceToken}'
    sqlDatabasePrivateEndpoint: 'pe-sqldb-${resourceToken}'
    sqlServer: 'sql-${resourceToken}'
    sqlResourceGroup: 'rg-${workloadName}-${environment}-${location}-workload'
    webAppService: 'app-web-${resourceToken}'
    webAppServicePlan: 'asp-web-${resourceToken}'
    webApplicationFirewall: 'waf${resourceToken}'
    webManagedIdentity: 'id-web-${resourceToken}'
    webPrivateEndpoint: 'pe-web-${resourceToken}'

    /*
    ** Administrative Resources - Jumpbox, Build Agents, etc.
    */
    buildAgent: 'vm-build-${resourceToken}'
    buildAgentPublicIpAddress: 'pip-build-${resourceToken}'
    jumpbox: 'vm-jump-${resourceToken}'
    jumpboxPublicIpAddress: 'pip-jump-${resourceToken}'
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
    hubRouteTable: contains(overrides, 'hubRouteTable') && !empty(overrides.hubRouteTable) ? overrides.hubRouteTable : defaultResourceNames.hubRouteTable
    hubVirtualNetwork: contains(overrides, 'hubVirtualNetwork') && !empty(overrides.hubVirtualNetwork) ? overrides.hubVirtualNetwork : defaultResourceNames.hubVirtualNetwork

    /*
    ** Spoke Networking Resources
    */
    spokeApiInboundSubnet: contains(overrides, 'spokeApiInboundSubnet') && !empty(overrides.spokeApiInboundSubnet) ? overrides.spokeApiInboundSubnet : defaultResourceNames.spokeApiInboundSubnet
    spokeApiOutboundSubnet: contains(overrides, 'spokeApiOutboundSubnet') && !empty(overrides.spokeApiOutboundSubnet) ? overrides.spokeApiOutboundSubnet : defaultResourceNames.spokeApiOutboundSubnet
    spokeBuildAgentSubnet: contains(overrides, 'spokeBuildAgentSubnet') && !empty(overrides.spokeBuildAgentSubnet) ? overrides.spokeBuildAgentSubnet : defaultResourceNames.spokeBuildAgentSubnet
    spokeConfigurationSubnet: contains(overrides, 'spokeConfigurationSubnet') && !empty(overrides.spokeConfigurationSubnet) ? overrides.spokeConfigurationSubnet : defaultResourceNames.spokeConfigurationSubnet
    spokeJumpboxSubnet: contains(overrides, 'spokeJumpboxSubnet') && !empty(overrides.spokeJumpboxSubnet) ? overrides.spokeJumpboxSubnet : defaultResourceNames.spokeJumpboxSubnet
    spokeStorageSubnet: contains(overrides, 'spokeStorageSubnet') && !empty(overrides.spokeStorageSubnet) ? overrides.spokeStorageSubnet : defaultResourceNames.spokeStorageSubnet
    spokeWebInboundSubnet: contains(overrides, 'spokeWebInboundSubnet') && !empty(overrides.spokeWebInboundSubnet) ? overrides.spokeWebInboundSubnet : defaultResourceNames.spokeWebInboundSubnet
    spokeWebOutboundSubnet: contains(overrides, 'spokeWebOutboundSubnet') && !empty(overrides.spokeWebOutboundSubnet) ? overrides.spokeWebOutboundSubnet : defaultResourceNames.spokeWebOutboundSubnet
    spokeResourceGroup: contains(overrides, 'spokeResourceGroup') && !empty(overrides.spokeResourceGroup) ? overrides.spokeResourceGroup : defaultResourceNames.spokeResourceGroup
    spokeVirtualNetwork: contains(overrides, 'spokeVirtualNetwork') && !empty(overrides.spokeVirtualNetwork) ? overrides.spokeVirtualNetwork : defaultResourceNames.spokeVirtualNetwork

    /*
    ** Shared Monitoring Resources
    */
    applicationInsights: contains(overrides, 'applicationInsights') && !empty(overrides.applicationInsights) ? overrides.applicationInsights : defaultResourceNames.applicationInsights
    applicationInsightsDashboard: contains(overrides, 'applicationInsightsDashboard') && !empty(overrides.applicationInsightsDashboard) ? overrides.applicationInsightsDashboard : defaultResourceNames.applicationInsightsDashboard
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
    ** Administrative Resources - Jumpbox, Build Agents, etc.
    */
    buildAgent: contains(overrides, 'buildAgent') && !empty(overrides.buildAgent) ? overrides.buildAgent : defaultResourceNames.buildAgent
    buildAgentPublicIpAddress: contains(overrides, 'buildAgentPublicIpAddress') && !empty(overrides.buildAgentPublicIpAddress) ? overrides.buildAgentPublicIpAddress : defaultResourceNames.buildAgentPublicIpAddress
    jumpbox: contains(overrides, 'jumpbox') && !empty(overrides.jumpbox) ? overrides.jumpbox : defaultResourceNames.jumpbox
    jumpboxPublicIpAddress: contains(overrides, 'jumpboxPublicIpAddress') && !empty(overrides.jumpboxPublicIpAddress) ? overrides.jumpboxPublicIpAddress : defaultResourceNames.jumpboxPublicIpAddress
}
