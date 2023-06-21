// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type Environment = {
  @description('The name of the Azure Developer environment - user chosen')
  name: string

  @description('If true, we are deploying a production environment.  This is used to size resources appropriately.')
  isProduction: bool

  @description('If true, we want network isolation via a virtual network and private endpoints')
  isNetworkIsolated: bool

  @description('The default region we want the resources to be created in')
  location: string

  @description('The running user/service principal; use a blank string to not use a principalId')
  principalId: string

  @description('A token that is used in generating names for resources.  This is unique to the environment and region')
  resourceToken: string

  @description('A list of default tags to apply to all resources')
  tags: object

  @description('If true, use a common app service plan; if false, create an app service plan per app service')
  useCommonAppServicePlan: bool

  @description('If true, use an existing SQL server; if false, create a new SQL server')
  useExistingSqlServer: bool
}

type DiagnosticSettings = {
  @description('The name of the Log Analytics Workspace')
  logAnalyticsWorkspaceName: string

  @description('The audit log retention policy')
  auditLogRetentionInDays: int

  @description('The diagnostic log retention policy')
  diagnosticLogRetentionInDays: int

  @description('If true, enable audit logging')
  enableAuditLogs: bool

  @description('If true, enable diagnostic logging')
  enableDiagnosticLogs: bool
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The environment we are provisioning for')
param environment Environment

/*
** Resources to create
*/
@description('The name of the virtual network')
param virtualNetworkName string

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var dnsZones = [
  'privatelink.azconfig.io'                                       // Azure App Configuration
  'privatelink.azurewebsites.net'                                 // Azure App Service
  'privatelink.vaultcore.azure.net'                               // Azure Key Vault
  'privatelink${az.environment().suffixes.sqlServerHostname}'     // Azure SQL Server
]

var api_inbound_subnet_name = 'backend-inbound'
var api_outbound_subnet_name = 'backend-outbound'
var configuration_subnet_name = 'configuration'
var devops_subnet_name = 'devops'
var storage_subnet_name = 'storage'
var web_inbound_subnet_name = 'frontend-inbound'
var web_outbound_subnet_name = 'frontend-outbound'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module virtualNetwork '../azure/network/virtual-network.bicep' = if (environment.isNetworkIsolated) {
  name: 'virtual-network'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: virtualNetworkName
    tags: environment.tags

    // The address prefix for the entire VNET.
    addressPrefix: '10.0.0.0/16'

    // The subnets to provision
    subnets: [
      {
        name: configuration_subnet_name
        properties: {
          addressPrefix: '10.0.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: storage_subnet_name
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: web_inbound_subnet_name
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: web_outbound_subnet_name
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: api_inbound_subnet_name
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: api_outbound_subnet_name
        properties: {
          addressPrefix: '10.0.5.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
      {
        name: devops_subnet_name
        properties: {
          addressPrefix: '10.0.254.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
    ]
  }
}

module privateDnsZones '../azure/network/private-dns-zone.bicep' = [ for zone in dnsZones: if (environment.isNetworkIsolated) {
  name: 'private-dns-zone-${zone}'
  params: {
    name: zone
    tags: environment.tags
    virtualNetworkName: virtualNetwork.outputs.name
  }
}]

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output virtual_network_name string = virtualNetwork.outputs.name

// Subnet Names for the VNET integration.  These are used by the app services to connect to the VNET.
output api_inbound_subnet_name string = api_inbound_subnet_name
output api_outbound_subnet_name string = api_outbound_subnet_name
output configuration_subnet_name string = configuration_subnet_name
output devops_subnet_name string = devops_subnet_name
output storage_subnet_name string = storage_subnet_name
output web_inbound_subnet_name string = web_inbound_subnet_name
output web_outbound_subnet_name string = web_outbound_subnet_name
