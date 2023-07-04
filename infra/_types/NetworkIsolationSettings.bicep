@description('A type describing the network isolation settings for a module.')
type NetworkIsolationSettings = {
  @description('The name of the private endpoint subnet, for inbound traffic')
  inboundSubnetName: string

  @description('The name of the VNET integration subnet, for outbound traffic')
  outboundSubnetName: string

  @description('The name of the virtual network holding the subnets')
  virtualNetworkName: string

  @description('The resource group holding the virtual network')
  resourceGroupName: string
}
