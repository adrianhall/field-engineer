// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

// This bicep file should be deployed with a scope == the resource group of the "local" virtual network

@description('The name of the peering')
param name string

@description('The name of the local virtual network')
param virtualNetworkName string

@description('The ID of the remote virtual network')
param remoteVirtualNetworkId string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: virtualNetworkName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-11-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    allowVirtualNetworkAccess: true
    allowGatewayTransit: false
    allowForwardedTraffic: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkId
    }
  }
}
