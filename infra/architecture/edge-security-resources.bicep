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
** Resources to potentially create
*/
@description('The name of the Azure Front Door endpoint to create')
param frontDoorEndpointName string

@description('The name of the Azure Front Door profile to create')
param frontDoorProfileName string

@description('The name of the Web Application Firewall to create')
param webApplicationFirewallName string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module frontDoor '../azure/security/front-door-with-waf.bicep' = {
  name: 'front-door-with-waf'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    tags: environment.tags

    // Resource names
    frontDoorEndpointName: frontDoorEndpointName
    frontDoorProfileName: frontDoorProfileName
    webApplicationFirewallName: webApplicationFirewallName

    // Service settings
    managedRules: [
      { name: 'Microsoft_DefaultRuleSet', version: '2.0' }
      { name: 'Microsoft_BotManagerRuleSet', version: '1.0' }
    ]
    sku: environment.isProduction || environment.isNetworkIsolated ? 'Premium' : 'Standard'
  }
}

output front_door_endpoint_name string = frontDoor.outputs.front_door_endpoint_name
output front_door_profile_name string = frontDoor.outputs.front_door_profile_name
output web_application_firewall_name string = frontDoor.outputs.web_application_firewall_name

output hostname string = frontDoor.outputs.hostname
output uri string = frontDoor.outputs.uri
