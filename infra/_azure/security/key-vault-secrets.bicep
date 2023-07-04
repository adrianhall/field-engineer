// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type KeyVaultSecret = {
  @description('The key for the secret')
  key: string

  @description('The value of the secret')
  value: string
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the resource')
param name string

@description('The list of secrets to install')
param secrets KeyVaultSecret[]

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: name
}

resource keyVaultSecrets 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = [ for secret in secrets: {
  name: secret.key
  parent: keyVault
  properties: {
    contentType: 'text/plain; charset=utf-8'
    value: secret.value
  }
}]
