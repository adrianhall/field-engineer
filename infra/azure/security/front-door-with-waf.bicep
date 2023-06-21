// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

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

type WAFRuleSet = {
  @description('The name of the rule set')
  name: string

  @description('The version of the rule set')
  version: string
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The Azure region to create the resource in')
param location string

@description('The tags to associate with the resource')
param tags object

/*
** Resource names to create
*/
@description('The name of the Azure Front Door endpoint to create')
param frontDoorEndpointName string

@description('The name of the Azure Front Door profile to create')
param frontDoorProfileName string

@description('The name of the Web Application Firewall to create')
param webApplicationFirewallName string

/*
** Service settings
*/
@description('A list of managed rule sets to enable')
param managedRules WAFRuleSet[]

@allowed([ 'Premium', 'Standard' ])
@description('The pricing plan to use for the Azure Front Door and Web Application Firewall')
param sku string

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var auditLogCategories = diagnosticSettings.enableAuditLogs ? [

] : []

var diagnosticLogCategories = diagnosticSettings.enableDiagnosticLogs ? [
  'FrontDoorAccessLog'
  'FrontDoorWebApplicationFirewallLog'
] : []

var auditLogSettings = map(auditLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.auditLogRetentionInDays, enabled: true }
})
var diagnosticLogSettings = map(diagnosticLogCategories, category => { 
  category: category, enabled: true, retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true } 
})
var logSettings = concat(auditLogSettings, diagnosticLogSettings)

// Convert the managed rule sets list into the object form required by the web application firewall
var managedRuleSets = map(managedRules, rule => {
  ruleSetType: rule.name
  ruleSetVersion: rule.version
  ruleSetAction: 'Block'
  ruleGroupOverrides: []
  exclusions: []
})

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: '${sku}_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: webApplicationFirewallName
  location: location
  tags: tags
  sku: {
    name: '${sku}_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: []
    }
    managedRules: {
      managedRuleSets: sku == 'Premium' ? managedRuleSets : []
    }
  }
}

resource wafPolicyLink 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  name: '${webApplicationFirewallName}-link'
  parent: frontDoorProfile
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            { id: frontDoorEndpoint.id }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${frontDoorProfileName}-diagnostics'
  scope: frontDoorProfile
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', diagnosticSettings.logAnalyticsWorkspaceName)
    logs: logSettings
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true }
      }
    ]
  }
}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

output front_door_profile_name string = frontDoorProfile.name
output front_door_endpoint_name string = frontDoorEndpoint.name
output web_application_firewall_name string = wafPolicy.name

output hostname string = frontDoorEndpoint.properties.hostName
output uri string = 'https://${frontDoorEndpoint.properties.hostName}'
