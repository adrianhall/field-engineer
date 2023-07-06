// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the private endpoint resource.  By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string?

  @description('The name of the resource group to hold the private endpoint.  By default, this uses the same resource group as the resource.')
  resourceGroupName: string?

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}
