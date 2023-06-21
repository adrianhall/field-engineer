// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Service Settings
*/
@description('The kind of application that this resource is monitoring')
@allowed([ 'web', 'ios', 'other', 'store', 'java', 'phone' ])
param kind string = 'web'

/*
** Dependencies
*/
@description('The ID of the associated Log Analytics Workspace')
param logAnalyticsWorkspaceId string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  kind: kind
  location: location
  tags: tags
  properties: {
    Application_Type: kind == 'web' ? 'web' : 'other'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = applicationInsights.id
output name string = applicationInsights.name
