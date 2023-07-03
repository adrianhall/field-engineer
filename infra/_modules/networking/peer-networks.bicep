targetScope = 'subscription'

// =====================================================================================================================
//     PARAMETERS - ALL PARAMETERS ARE REQUIRED IN MODULES
// =====================================================================================================================

/*
** Dependencies
*/
@description('The (pre-existing) resource group holding the hub virtual network')
param hubResourceGroupName string

@description('The ID of the Hub Virtual Network')
param hubVirtualNetworkName string

@description('The name of the resource group holding the spoke virtual network')
param spokeResourceGroupName string

@description('The ID of the spoke virtual network to peer with the hub')
param spokeVirtualNetworkName string

// =====================================================================================================================
//     AZURE MODULES
// =====================================================================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hubResourceGroupName
}

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: hubVirtualNetworkName
  scope: hubResourceGroup
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: spokeResourceGroupName
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: spokeVirtualNetworkName
  scope: spokeResourceGroup
}

module peerSpokeToHub '../../_azure/networking/peer-virtual-network.bicep' = {
  name: 'peer-spoke-to-hub'
  scope: spokeResourceGroup
  params: {
    name: 'peerTo-${hubVirtualNetwork.name}'
    virtualNetworkName: spokeVirtualNetwork.name
    remoteVirtualNetworkId: hubVirtualNetwork.id
  }
}

module peerHubToSpoke '../../_azure/networking/peer-virtual-network.bicep' = {
  name: 'peer-hub-to-spoke'
  scope: hubResourceGroup
  params: {
    name: 'peerTo-${spokeVirtualNetwork.name}'
    virtualNetworkName: hubVirtualNetwork.name
    remoteVirtualNetworkId: spokeVirtualNetwork.id
  }
}
