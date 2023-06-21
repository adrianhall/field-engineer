// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The location of the resource')
param location string = resourceGroup().location

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Service settings
*/
@description('The DNS Zone name to register this private endpoint into')
param dnsZoneName string

@description('The list of group IDs to redirect through this private link')
param groupIds string[]

@description('The name of the linked service resource')
param linkServiceName string

@description('The resource ID for the linked service')
param linkServiceId string

@description('The name of the subnet hosting the private links')
param subnetName string

@description('The name of the virtual network hosting the private links')
param virtualNetworkName string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
    }
    privateLinkServiceConnections: [
      {
        name: linkServiceName
        properties: {
          privateLinkServiceId: linkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource dnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: 'mydnsgroupname'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: dnsZoneName
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', dnsZoneName)
        }
      }
    ]
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = privateEndpoint.id
output name string = privateEndpoint.name
