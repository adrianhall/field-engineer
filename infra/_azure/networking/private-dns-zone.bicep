// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The DNS zone to create')
param name string

@description('The tags to associate with the private DNS zone')
param tags object

@description('The ID of the virtual network to link this DNS Zone to')
param virtualNetworkId string

// =====================================================================================================================
//     AZURE RESOURCeS
// =====================================================================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
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
        id: virtualNetworkId
      }
    }
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output name string = privateDnsZone.name
