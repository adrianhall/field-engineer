// ========================================================================
//     USER-DEFINED TYPES
// ========================================================================

/*
** From: infra/_types/AutoScaleSettings.bicep
*/
@description('A type that describes auto-scaling via Insights')
type AutoScaleSettings = {
  @description('The minimum number of scale units to provision')
  minCapacity: int?

  @description('The maximum number of scale units to provision')
  maxCapacity: int?

  @description('The CPU Percentage at which point to scale in')
  scaleInThreshold: int?

  @description('The CPU Percentage at which point to scale out')
  scaleOutThreshold: int?
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

// ========================================================================
//     PARAMETERS
// ========================================================================

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

/*
** Service Settings
*/
@description('If set, the auto-scale settings')
param autoScaleSettings AutoScaleSettings = {}

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@allowed([ 'Windows', 'Linux' ])
@description('The OS for the application that will be run on this App Service Plan.  Optional - default is Windows.')
param serverType string = 'Windows'

@allowed([ 'B1', 'B2', 'B3', 'EP1', 'EP2', 'EP3', 'P0v3', 'P1v3', 'P2v3', 'P3v3', 'S1', 'S2', 'S3' ])
@description('The SKU to use for the App Service Plan')
param sku string = 'B1'

@description('If true, set this App Service Plan up as zone redundant')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var defaultAutoScaleSettings = { minCapacity: 1, maxCapacity: 1, scaleInThreshold: 40, scaleOutThreshold: 75 }
var actualAutoScaleSettings = union(autoScaleSettings, defaultAutoScaleSettings)


// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set#example
var environmentConfigurationMap = {
  B1:   { name: 'B1',   tier: 'Basic',          size: 'B1',   family: 'B'   }
  B2:   { name: 'B2',   tier: 'Basic',          size: 'B2',   family: 'B'   }
  B3:   { name: 'B3',   tier: 'Basic',          size: 'B3',   family: 'B'   }
  EP1:  { name: 'EP1',  tier: 'ElasticPremium', size: 'EP1',  family: 'EP'  }
  EP2:  { name: 'EP2',  tier: 'ElasticPremium', size: 'EP2',  family: 'EP'  }
  EP3:  { name: 'EP3',  tier: 'ElasticPremium', size: 'EP3',  family: 'EP'  }
  P0v3: { name: 'P0v3', tier: 'PremiumV3',      size: 'P0v3', family: 'Pv3' }
  P1v3: { name: 'P1v3', tier: 'PremiumV3',      size: 'P1v3', family: 'Pv3' }
  P2v3: { name: 'P2v3', tier: 'PremiumV3',      size: 'P2v3', family: 'Pv3' }
  P3v3: { name: 'P3v3', tier: 'PremiumV3',      size: 'P3v3', family: 'Pv3' }
  S1:   { name: 'S1',   tier: 'Standard',       size: 'S1',   family: 'S'   }
  S2:   { name: 'S2',   tier: 'Standard',       size: 'S2',   family: 'S'   }
  S3:   { name: 'S3',   tier: 'Standard',       size: 'S3',   family: 'S'   }
}

// ========================================================================
//     AZURE RESOURCES
// ========================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: environmentConfigurationMap[sku].name
    tier: environmentConfigurationMap[sku].tier
    size: environmentConfigurationMap[sku].size
    family: environmentConfigurationMap[sku].family
    capacity: (environmentConfigurationMap[sku].tier == 'PremiumV3' && zoneRedundant) ? 3 : 1
  }
  kind: startsWith(sku, 'EP') ? 'elastic' : (serverType == 'Windows' ? '' : 'linux')
  properties: {
    perSiteScaling: true
    maximumElasticWorkerCount: (actualAutoScaleSettings.maxCapacity < 3 && zoneRedundant) ? 3 : actualAutoScaleSettings.maxCapacity
    reserved: serverType == 'Linux'
    targetWorkerCount: (actualAutoScaleSettings.minCapacity < 3 && zoneRedundant) ? 3 : actualAutoScaleSettings.minCapacity
    zoneRedundant: zoneRedundant
  }
}

resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (!startsWith(sku, 'EP') && actualAutoScaleSettings.maxCapacity > actualAutoScaleSettings.minCapacity) {
  name: '${name}-autoscale'
  location: location
  tags: tags
  properties: {
    targetResourceUri: appServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: string(zoneRedundant ? 3 : actualAutoScaleSettings.minCapacity)
          maximum: string(actualAutoScaleSettings.maxCapacity)
          default: string(zoneRedundant ? 3 : actualAutoScaleSettings.minCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: actualAutoScaleSettings.scaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: actualAutoScaleSettings.scaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagnostics'
  scope: appServicePlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { days: diagnosticSettings.diagnosticLogRetentionInDays, enabled: true }
      }
    ]
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output id string = appServicePlan.id
output name string = appServicePlan.name
