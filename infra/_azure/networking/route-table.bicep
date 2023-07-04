// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The location for the resource')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with this resource')
param tags object = {}

/*
** Settings
*/
@description('Optional. Switch to disable BGP route propagation.')
param disableBgpRoutePropagation bool = false

@description('The list of routes to install in the route table')
param routes object[]

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource routeTable 'Microsoft.Network/routeTables@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    routes: routes
    disableBgpRoutePropagation: disableBgpRoutePropagation
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = routeTable.id
output name string = routeTable.name
