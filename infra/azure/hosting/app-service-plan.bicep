// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

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

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Service Settings
*/
@description('If set, the auto-scale settings')
param autoScaleSettings AutoScaleSettings = {}

@allowed([ 'EP1', 'EP2', 'EP3', 'F1', 'D1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P0v3', 'P1v3', 'P2v3', 'P3v3', 'P1mv3', 'P2mv3', 'P3mv3', 'P4mv3', 'P5mv3' ])
@description('The SKU to use for the App Service Plan')
param sku string = 'F1'

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var defaultAutoScaleSettings = { minCapacity: 1, maxCapacity: 1, scaleInThreshold: 40, scaleOutThreshold: 75 }
var actualAutoScaleSettings = union(autoScaleSettings, defaultAutoScaleSettings)

var servicePlanProperties = startsWith(sku, 'EP') ? {
  maximumElasticWorkerCount: actualAutoScaleSettings.maxCapacity
} : {
  perSiteScaling: (actualAutoScaleSettings.maxCapacity > actualAutoScaleSettings.minCapacity)
}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: startsWith(sku, 'EP') ? 'elastic' : 'app'
  properties: servicePlanProperties
}

resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (actualAutoScaleSettings.maxCapacity > actualAutoScaleSettings.minCapacity) {
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
          minimum: string(actualAutoScaleSettings.minCapacity)
          maximum: string(actualAutoScaleSettings.maxCapacity)
          default: string(actualAutoScaleSettings.minCapacity)
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

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(diagnosticSettings.logAnalyticsWorkspaceName)) {
  name: '${name}-diagnostics'
  scope: appServicePlan
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', diagnosticSettings.logAnalyticsWorkspaceName)
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

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = appServicePlan.id
output name string = appServicePlan.name
