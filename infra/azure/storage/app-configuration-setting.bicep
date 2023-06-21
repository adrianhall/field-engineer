// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The Azure region to use for running this operation')
param location string = resourceGroup().location

@description('The list of tags to use for this operation')
param tags object = {}

@description('The managed identity to use for running the operation')
param ownerManagedIdentityName string

@description('The Name for the App Configuration service')
param appConfigurationName string

@description('The endpoint to use for the App Configuration service')
param endpoint string = ''

@description('If true, the value is a secret and should be stored in Key Vault')
param isSecret bool = false

@description('The name of the Key Vault resource')
param keyVaultName string

@description('The key name')
param settingName string

@description('The key value')
param settingValue string

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource ownerManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: ownerManagedIdentityName
}

module keyVaultValue './key-vault-secret.bicep' = if (isSecret) {
  name: 'kv-config-setting-${uniqueString(settingName)}'
  params: {
    keyVaultName: keyVaultName
    secretName: settingName
    secretValue: settingValue
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'appconfig-script-${uniqueString(settingName)}'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${ownerManagedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azPowerShellVersion: '9.7'
    retentionInterval: 'PT1H'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    arguments: join([
      '-AppConfigurationUri \'${appConfiguration.properties.endpoint}\''
      '-Key \'${settingName}\''
      '-Value \'${base64(settingValue)}\''
      '-Secret \'${isSecret}\''
    ], ' ')
    scriptContent: loadTextContent('./scripts/set-appconfig-setting.ps1')
  }
}
