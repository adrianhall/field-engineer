// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the dashboard to create; leave blank to not create a dashboard')
param dashboardName string = ''

@description('The Azure region to deploy this resource into.')
param location string

@description('The name of the main resource to deploy.')
param name string

@description('The tags to associate with the resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The Resource ID for the Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

/*
** Settings
*/
@allowed([ 'web', 'ios', 'other', 'store', 'java', 'phone' ])
param kind string = 'web'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource createdResource 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: kind
  tags: tags
  properties: {
    Application_Type: kind == 'web' ? 'web' : 'other'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

module dashboard './application-insights-dashboard.bicep' = if (!empty(dashboardName)) {
  name: dashboardName
  params: {
    name: dashboardName
    location: location
    tags: tags
    applicationInsightsName: createdResource.name
  }
}

// ========================================================================
// VARIABLES
// ========================================================================

output id string = createdResource.id
output name string = createdResource.name
