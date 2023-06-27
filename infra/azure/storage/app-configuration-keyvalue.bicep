// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the App Configuration resource')
param appConfigurationName string

@description('The name of the key.')
param key string

@description('The value of the key.')
param value string

@description('The content type for the key.')
param contentType string = 'text/plain;charset=utf-8'

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName

  resource keyValue 'keyValues' = {
    name: key
    properties: {
      contentType: contentType
      value: value
    }
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output name string = appConfiguration::keyValue.name
