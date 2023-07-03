/*
** From: infra/_types/PrivateEndpointSettings.bicep
*/
@description('The settings for a private endpoint')
type PrivateEndpointSettings = {
  @description('The name of the private endpoint resource')
  name: string

  @description('The name of the resource group to hold the private endpoint')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to')
  subnetId: string
}
