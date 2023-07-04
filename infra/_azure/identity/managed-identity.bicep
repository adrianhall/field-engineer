// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the resource')
param name string

@description('The Azure region to create the resource in')
param location string

@description('The tags to associate with the resource')
param tags object

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output id string = managedIdentity.id
output name string = managedIdentity.name
output principal_id string = managedIdentity.properties.principalId
