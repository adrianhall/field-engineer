targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Resource Naming
//  Copyright (C) 2023 Microsoft, Inc.
//
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
** From infra/_types/NetworkSettings.bicep
*/
@description('Type that describes the network settings for a single network')
type NetworkSettings = {
  @description('The address space for the virtual network')
  addressSpace: string

  @description('The list of subnets, with their associated address prefixes')
  addressPrefixes: object
}

/*
** This module create a hub network, if it is requested.
*/

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The network settings for the hub network')
param networkSettings NetworkSettings

@description('The list of resource names to use')
param resourceNames object

@description('The tags to use for all resources')
param tags object

// ========================================================================
// VARIABLES
// ========================================================================

// ========================================================================
// AZURE RESOURCES
// ========================================================================

module logAnalytics '../../_azure/monitoring/log-analytics.bicep' = {
  name: 'hub-log-analytics'
  params: {
    location: location
    name: resourceNames.logAnalyticsWorkspace
    tags: tags

    // Settings
    sku: deploymentSettings.isProduction ? 'PerGB2018' : 'Free'
  }
}

module applicationInsights '../../_azure/monitoring/application-insights.bicep' = {
  name: 'hub-application-insights'
  params: {
    location: location
    name: resourceNames.applicationInsights
    dashboardName: resourceNames.applicationInsightsDashboard

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspace_id
  }
}

module virtualNetwork '../../_azure/networking/virtual-network.bicep' = {
  name: 'hub-virtual-network'
  params: {
    location: location
    name: resourceNames.hubVirtualNetwork
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspace_id

    // Settings
    addressSpace: networkSettings.addressSpace
    diagnosticSettings: diagnosticSettings
    subnets: [
      {
        name: resourceNames.bastionSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.bastion
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.firewallSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.firewall
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

module bastionHost '../../_azure/security/bastion.bicep' = {
  name: 'hub-bastion-host'
  params: {
    location: location
    name: resourceNames.bastion
    publicIpAddressName: resourceNames.bastionPublicIpAddress
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspace_id

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicIpAddress: true
    sku: 'Standard'
    subnetId: virtualNetwork.outputs.subnets[0].id
    zoneRedundant: deploymentSettings.isProduction
  }
}

module firewall '../../_azure/security/firewall.bicep' = {
  name: 'hub-firewall'
  params: {
    location: location
    name: resourceNames.firewall
    publicIpAddressName: resourceNames.firewallPublicIpAddress
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspace_id

    // Settings
    applicationRules: applicationRules
    diagnosticSettings: diagnosticSettings
    networkRules: networkRules
    subnetId: virtualNetwork.outputs.subnets[1].id
  }
}

module routeTable '../../_azure/networking/route-table.bicep' = {
  name: 'hub-route-table'
  params: {
    location: location
    name: resourceNames.routeTable
    tags: tags

    // Settings
    routes: [
      {
        name: 'defaultEgress'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: firewall.outputs.internal_ip_address
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output workspace_id string = logAnalytics.outputs.workspace_id
output virtual_network_name string = virtualNetwork.outputs.name
output route_table_id string = routeTable.outputs.id
