// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the user-assigned managed identity to assign to the role')
param managedIdentityName string

@description('The environment resource token used to generate unique names')
param resourceToken string

@description('The ID of the role definition to assign')
param roleId string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleId, managedIdentity.name, resourceToken)
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: managedIdentity.properties.principalId
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output name string = roleAssignment.name
