targetScope = 'subscription'

/*
** Hub Network Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network consists of a virtual network that hosts resources that
** are generally associated with a hub.
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

@description('If set, the ID of the table holding the outbound route to the firewall in the hub network')
param routeTableId string = ''

/*
** Settings
*/
@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string = '10.0.16.0/20'

@description('If true, create a subnet for Devops resources')
param createDevopsSubnet bool = false

@description('The list of private DNS zones to create in this virtual network.')
param privateDnsZones array = [
  'privatelink.vaultcore.azure.net'
  'privatelink${az.environment().suffixes.sqlServerHostname}'
  'privatelink.azurewebsites.net'
]

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

// The subnet prefixes for the individual subnets inside the virtual network
var subnetPrefixes = [ for i in range(0, 16): cidrSubnet(addressPrefix, 26, i)]

// When creating the virtual network, we need to set up a service delegation for app services.
var appServiceDelegation = [
  {
    name: 'ServiceDelegation'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]

// Network security group rules
var allowHttpsInbound = {
  name: 'Allow-HTTPS-Inbound'
  properties: {
    access: 'Allow'
    description: 'Allow HTTPS inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '443'
    direction: 'Inbound'
    priority: 100
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

var allowSqlInbound = {
  name: 'Allow-SQL-Inbound'
  properties: {
    access: 'Allow'
    description: 'Allow SQL inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '1433'
    direction: 'Inbound'
    priority: 110
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

var denyAllInbound = {
  name: 'Deny-All-Inbound'
  properties: {
    access: 'Deny'
    description: 'Deny all inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
    direction: 'Inbound'
    priority: 1000
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

// Sets up the route table when there is one specified.
var routeTableSettings = !empty(routeTableId) ? {
  routeTable: { id: routeTableId }
} : {}

var deploymentSubnet = [{
  name: resourceNames.spokeDeploymentSubnet
  properties: union({
    addressPrefix: subnetPrefixes[5]
    privateEndpointNetworkPolicies: 'Disabled'
  }, routeTableSettings)
}]

var devopsSubnet = createDevopsSubnet ? [{
  name: resourceNames.spokeDevopsSubnet
  properties: union({
    addressPrefix: subnetPrefixes[6]
    privateEndpointNetworkPolicies: 'Disabled'
  }, routeTableSettings)
}] : []

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.spokeResourceGroup
}

module apiInboundNSG '../core/network/network-security-group.bicep' = {
  name: 'spoke-api-inbound-nsg'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeApiInboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      denyAllInbound
    ]
  }
}

module apiOutboundNSG '../core/network/network-security-group.bicep' = {
  name: 'spoke-api-outbound-nsg'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeApiOutboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      denyAllInbound
    ]
  }
}

module storageNSG '../core/network/network-security-group.bicep' = {
  name: 'spoke-storage-nsg'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeStorageNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      allowSqlInbound
      denyAllInbound
    ]
  }
}

module webInboundNSG '../core/network/network-security-group.bicep' = {
  name: 'spoke-web-inbound-nsg'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeWebInboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      denyAllInbound
    ]
  }
}

module webOutboundNSG '../core/network/network-security-group.bicep' = {
  name: 'spoke-web-outbound-nsg'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeWebOutboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      denyAllInbound
    ]
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: 'spoke-virtual-network'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeVirtualNetwork
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressPrefix: addressPrefix
    diagnosticSettings: diagnosticSettings
    subnets: union([
      {
        name: resourceNames.spokeStorageSubnet
        properties: {
          addressPrefix: subnetPrefixes[0]
          networkSecurityGroup: { id: storageNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiInboundSubnet
        properties: {
          addressPrefix: subnetPrefixes[1]
          networkSecurityGroup: { id: apiInboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiOutboundSubnet
        properties: union({
          addressPrefix: subnetPrefixes[2]
          delegations: appServiceDelegation
          networkSecurityGroup: { id: apiOutboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Enabled'
        }, routeTableSettings)
      }
      {
        name: resourceNames.spokeWebInboundSubnet
        properties: {
          addressPrefix: subnetPrefixes[3]
          networkSecurityGroup: { id: webInboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeWebOutboundSubnet
        properties: union({
          addressPrefix: subnetPrefixes[4]
          delegations: appServiceDelegation
          networkSecurityGroup: { id: webOutboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Enabled'
        }, routeTableSettings)
      }], deploymentSubnet, devopsSubnet)
  }
}

module dnsZones '../core/network/private-dns-zone.bicep' = [ for dnsZoneName in privateDnsZones: {
  name: 'dns-zone-${dnsZoneName}'
  scope: resourceGroup
  params: {
    name: dnsZoneName
    tags: moduleTags
    virtualNetworkId: virtualNetwork.outputs.id
  }
}]

// ========================================================================
// OUTPUTS
// ========================================================================

output virtual_network_id string = virtualNetwork.outputs.id
output virtual_network_name string = virtualNetwork.outputs.name
output subnets object = virtualNetwork.outputs.subnets
