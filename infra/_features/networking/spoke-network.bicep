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

@description('If set, the route table holding the outbound route for the hub network')
param routeTableId string = ''

/*
** Module specific settings
*/
@description('The list of private DNS zones to create.')
param privateDnsZones string[] = [
  'privatelink.azconfig.io'
  'privatelink.vaultcore.azure.net'
  'privatelink${az.environment().suffixes.sqlServerHostname}'
  'privatelink.azurewebsites.net'
]

// ========================================================================
// PARAMETERS
// ========================================================================

// Rule used in NSGs to allow inbound HTTPS traffic.
var allowHttpsInbound = {
  name: 'Allow-Https-Inbound'
  properties: {
    access: 'Allow'
    description: 'Allow HTTPS inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '443'
    direction: 'Inbound'
    priority: 110
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

// Rule used in NSGs to deny all inbound traffic.
var denyAllInbound = {
  name: 'Deny-All-Inbound'
  properties: {
    access: 'Deny'
    description: 'Deny all inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
    direction: 'Inbound'
    priority: 1000
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

// List of subnets allowed to access storage components
var allowedStorageSubnets = [
  networkSettings.addressPrefixes.apiOutbound
  networkSettings.addressPrefixes.buildAgent
  networkSettings.addressPrefixes.jumphost
  networkSettings.addressPrefixes.devops
]

// ========================================================================
// AZURE MODULES
// ========================================================================

module configurationNSG '../../_azure/security/network-security-group.bicep' = {
  name: 'spoke-nsg-configuration'
  params: {
    name: resourceNames.configurationNetworkSecurityGroup
    location: location
    tags: tags

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

module storageNSG '../../_azure/security/network-security-group.bicep' = {
  name: 'spoke-nsg-storage'
  params: {
    name: resourceNames.storageNetworkSecurityGroup
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      {
        name: 'Allow-Https-Inbound'
        properties: {
          access: 'Allow'
          description: 'Allow HTTPS inbound traffic'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          sourceAddressPrefixes: allowedStorageSubnets
          sourcePortRange: '*'
        }
      }
      {
        name: 'Allow-Sql-Inbound'
        properties: {
          access: 'Allow'
          description: 'Allow Azure SQL inbound traffic'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          sourceAddressPrefixes: allowedStorageSubnets
          sourcePortRange: '*'
        }
      }
      denyAllInbound
    ]
  }
}

module httpInboundNSG '../../_azure/security/network-security-group.bicep' = {
  name: 'spoke-nsg-inbound-http'
  params: {
    name: resourceNames.inboundHttpNetworkSecurityGroup
    location: location
    tags: tags

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

module blockInboundNSG '../../_azure/security/network-security-group.bicep' = {
  name: 'spoke-nsg-block-inbound'
  params: {
    name: resourceNames.blockInboundNetworkSecurityGroup
    location: location
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      denyAllInbound
    ]
  }
}

module virtualNetwork '../../_azure/networking/virtual-network.bicep' = {
  name: 'spoke-virtual-network'
  params: {
    name: resourceNames.spokeVirtualNetwork
    location: location
    tags: tags
    
    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressSpace: networkSettings.addressSpace
    diagnosticSettings: diagnosticSettings
    subnets: [
      {
        name: resourceNames.spokeConfigurationSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.configuration
          networkSecurityGroup: {
            id: configurationNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeStorageSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.storage
          networkSecurityGroup: { 
            id: storageNSG.outputs.id 
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiInboundSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.apiInbound
          networkSecurityGroup: { 
            id: httpInboundNSG.outputs.id 
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiOutboundSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.apiOutbound
          delegations: [
            { 
              name: 'delegation'
              properties: { serviceName: 'Microsoft.Web/serverfarms' }
            }
          ]
          networkSecurityGroup: {
            id: blockInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          routeTable: !empty(routeTableId) ?{ 
            id: routeTableId 
          } : null
        }
      }
      {
        name: resourceNames.spokeWebInboundSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.webInbound
          networkSecurityGroup: {
            id: httpInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeWebOutboundSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.webOutbound
          delegations: [
            { 
              name: 'delegation'
              properties: { serviceName: 'Microsoft.Web/serverfarms' }
            }
          ]
          networkSecurityGroup: {
            id: blockInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          routeTable: !empty(routeTableId) ?{ 
            id: routeTableId 
          } : null
        }
      }
      {
        name: resourceNames.spokeBuildAgentSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.buildAgent
          networkSecurityGroup: {
            id: blockInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          routeTable: !empty(routeTableId) ?{ 
            id: routeTableId 
          } : null
        }
      }
      {
        name: resourceNames.spokeJumphostSubet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.jumphost
          networkSecurityGroup: {
            id: blockInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          routeTable: !empty(routeTableId) ?{ 
            id: routeTableId 
          } : null
        }
      }
      {
        name: resourceNames.spokeDevopsSubnet
        properties: {
          addressPrefix: networkSettings.addressPrefixes.devops
          networkSecurityGroup: {
            id: blockInboundNSG.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          routeTable: !empty(routeTableId) ?{ 
            id: routeTableId 
          } : null
        }
      }
    ]
  }
}

module dnsZones '../../_azure/networking/private-dns-zone.bicep' = [ for dnsZoneName in privateDnsZones: {
  name: 'dns-zone-${dnsZoneName}'
  params: {
    name: dnsZoneName
    tags: tags
    virtualNetworkId: virtualNetwork.outputs.id
  }
}]

// ========================================================================
// AZURE MODULES
// ========================================================================

output resource_group_name string = resourceGroup().name
output subnets object = toObject(virtualNetwork.outputs.subnets, subnet => subnet.name)
output virtual_network_name string = virtualNetwork.outputs.name
