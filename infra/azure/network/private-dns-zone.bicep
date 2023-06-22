// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

@description('The name of the virtual network to link this private DNS zone to')
param virtualNetworkName string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: virtualNetworkName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
  tags: tags
  
  resource virtualNetworkLink 'virtualNetworkLinks' = {
    name: '${name}-link'
    location: 'global'
    tags: tags
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: virtualNetwork.id
      }
    }
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = privateDnsZone.id
output name string = privateDnsZone.name
