// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The ID of the principal to assign to the role')
param principalId string

@allowed([ 'ServicePrincipal', 'User' ])
@description('The type of the principal to assign to the role')
param principalType string

@description('The ID of the role definition to assign')
param roleId string

// =====================================================================================================================
//     VARIABLES
// =====================================================================================================================

var resourceToken = uniqueString(subscription().id, resourceGroup().name, principalId, principalType)

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(roleId, principalId, resourceToken)
  properties: {
    principalType: principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: principalId
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output name string = roleAssignment.name
