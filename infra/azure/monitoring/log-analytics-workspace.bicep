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
@description('The pricing plan to use for the resource')
@allowed(['CapacityReservation', 'Free', 'LACluster', 'PerGB2018', 'PerNode', 'Premium', 'Standalone', 'Standard'])
param sku string = 'PerGB2018'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { 
      name: sku
    }
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
