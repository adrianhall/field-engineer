// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the private endpoint')
param name string

@description('The Azure region to create the private endpoint in')
param location string

@description('The tags to associate with the private endpoint')
param tags object

@description('The name of the DNS Zone')
param dnsZoneName string

@description('The name of the linked service')
param linkServiceName string

@description('The ID of the linked service')
param linkServiceId string

@description('The list of group IDs to redirect through the private link')
param groupIds string[]

@description('The virtual network hosting the private endpoints')
param subnetResourceId string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { 
      id: subnetResourceId
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
        name: 'config1'
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
