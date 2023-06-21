// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the Key Vault')
param keyVaultName string

@description('The name of the secret')
param secretName string

@secure()
@description('The value of the secret')
param secretValue string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: replace(secretName, ':', '--')
  parent: keyVault
  properties: {
    value: secretValue
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output uri string = '${keyVault.properties.vaultUri}secrets/${keyVaultSecret.name}'
