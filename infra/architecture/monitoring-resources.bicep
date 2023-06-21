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


// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The environment we are provisioning for')
param environment Environment

@description('The name of the Application Insights resource')
param applicationInsightsName string

@description('The name of the Application Insights Dashboard resource')
param applicationInsightsDashboardName string

@description('The name of the Log Analytics Workspace resource')
param logAnalyticsWorkspaceName string

// =====================================================================================================================
//     AZURE COMPONENTS
// =====================================================================================================================

module logAnalyticsWorkspace '../azure/monitoring/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  params: {
    name: logAnalyticsWorkspaceName
    location: environment.location
    tags: environment.tags
  }
}

module applicationInsights '../azure/monitoring/application-insights.bicep' = {
  name: 'application-insights'
  params: {
    name: applicationInsightsName
    location: environment.location
    tags: environment.tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module appInsightsDashboard '../azure/monitoring/application-insights-dashboard.bicep' = {
  name: 'app-insights-dashboard'
  params: {
    name: applicationInsightsDashboardName
    location: environment.location
    tags: environment.tags
    applicationInsightsName: applicationInsights.outputs.name
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output application_insights_name string = applicationInsights.outputs.name
output log_analytics_workspace_name string = logAnalyticsWorkspace.outputs.name
output log_analytics_dashboard_name string = appInsightsDashboard.outputs.name

output log_analytics_workspace_id string = logAnalyticsWorkspace.outputs.id
