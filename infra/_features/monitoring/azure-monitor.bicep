// ========================================================================
// PARAMETERS
// ========================================================================

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@description('The list of resource names to use')
param resourceNames object

@description('The tags to use for all resources')
param tags object


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
    sku: 'PerGB2018'
  }
}

module applicationInsights '../../_azure/monitoring/application-insights.bicep' = {
  name: 'hub-application-insights'
  params: {
    location: location
    name: resourceNames.applicationInsights
    dashboardName: resourceNames.applicationInsightsDashboard

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output resource_group_name string = resourceGroup().name
output application_insights_name string = applicationInsights.outputs.name
output log_analytics_workspace_id string = logAnalytics.outputs.id
