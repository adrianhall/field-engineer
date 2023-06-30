targetScope = 'resourceGroup'

// ========================================================================
//
//  Field Engineer Application
//  Hub Network Deployment
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
** From infra/_types/NetworkSettings.bicep
*/
@description('Type that describes the network settings for a single network')
type NetworkSettings = {
  @description('The address space for the virtual network')
  addressSpace: string

  @description('The list of subnets, with their associated address prefixes')
  addressPrefixes: object
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

@description('The network settings for the hub network')
param networkSettings NetworkSettings

@description('The list of resource names to use')
param resourceNames object

@description('The tags to use for all resources')
param tags object

/*
** Dependencies
*/
@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

/*
** Feature-dependent settings
*/
@description('The address spaces allowed to connect through the firewall.')
param allowedEgressAddresses string[] = []

@description('The address space allowed unrestricted outbound access through the firewall.')
param unrestrictedEgressAddresses string[] = []

// ========================================================================
// VARIABLES
// ========================================================================

// Some helpers for the firewall rules
var allowTraffic = { type: 'allow' }
var httpProtocol  = { port: '80', protocolType: 'HTTP' }
var httpsProtocol = { port: '443', protocolType: 'HTTPS' }
var azureFqdns = loadJsonContent('./azure-fqdns.jsonc')

var applicationRuleCollections = [
  {
    name: 'Azure-Monitor'
    properties: {
      action: allowTraffic
      priority: 201
      rules: [
        {
          name: 'allow-azure-monitor'
          protocols: [ httpsProtocol ]
          sourceAddresses: allowedEgressAddresses
          targetFqdns: azureFqdns.azureMonitor
        }
      ]
    }
  }
  {
    name: 'Core-Dependencies'
    properties: {
      action: allowTraffic
      priority: 200
      rules: [
        {
          name: 'allow-core-apis'
          protocols: [ httpsProtocol ]
          sourceAddresses: allowedEgressAddresses
          targetFqdns: azureFqdns.coreServices
        }
        {
          name: 'allow-developer-services'
          protocols: [ httpsProtocol ]
          sourceAddresses: allowedEgressAddresses
          targetFqdns: azureFqdns.developerServices
        }
        {
          name: 'allow-certificate-dependencies'
          protocols: [ httpProtocol, httpsProtocol ]
          sourceAddresses: allowedEgressAddresses
          targetFqdns: azureFqdns.certificateServices
        }
      ]
    }
  }
]

var networkRuleCollections = !empty(unrestrictedEgressAddresses) ? [
  {
    name: 'Unrestricted-Outbound'
    properties: {
      action: allowTraffic
      priority: 100
      rules: [
        {
          name: 'allow-unrestricted-outbound'
          destinationAddresses: [ '*' ]
          destinationPorts: [ '443' ]
          protocols: [ 'TCP' ]
          sourceAddresses: unrestrictedEgressAddresses
        }
      ]
    }
  }
] : []

// ========================================================================
// AZURE MODULES
// ========================================================================

module virtualNetwork '../../_azure/networking/virtual-network.bicep' = {
  name: 'hub-virtual-network'
  params: {
    location: location
    name: resourceNames.hubVirtualNetwork
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressSpace: networkSettings.addressSpace
    diagnosticSettings: diagnosticSettings
    subnets: [
      {
        name: resourceNames.hubBastionSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.bastion
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.hubFirewallSubnet
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
    name: resourceNames.hubBastion
    publicIpAddressName: resourceNames.hubBastionPublicIpAddress
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicIpAddress: true
    sku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    subnetId: virtualNetwork.outputs.subnets[0].id
    zoneRedundant: deploymentSettings.isProduction
  }
}

module firewall '../../_azure/security/firewall.bicep' = {
  name: 'hub-firewall'
  params: {
    location: location
    name: resourceNames.hubFirewall
    publicIpAddressName: resourceNames.hubFirewallPublicIpAddress
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    applicationRuleCollections: applicationRuleCollections
    diagnosticSettings: diagnosticSettings
    networkRuleCollections: networkRuleCollections
    subnetId: virtualNetwork.outputs.subnets[1].id
  }
}

module routeTable '../../_azure/networking/route-table.bicep' = {
  name: 'hub-route-table'
  params: {
    location: location
    name: resourceNames.hubRouteTable
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

output bastion_hostname string = bastionHost.outputs.hostname
output firewall_hostname string = firewall.outputs.hostname
output route_table_id string = routeTable.outputs.id
output virtual_network_name string = virtualNetwork.outputs.name
