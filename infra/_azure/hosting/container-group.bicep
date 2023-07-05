// ========================================================================
//     PARAMETERS
// ========================================================================

/*
** See https://learn.microsoft.com/en-us/azure/templates/microsoft.containerinstance/containergroups?pivots=deployment-language-bicep#environmentvariable
*/
type ContainerEnvironmentVariable = {
  @description('The name of the environment variable.')
  name: string
  @description('The value of the secure environment variable.')
  secureValue: string?
  @description('The value of the environment variable.')
  value: string?
}

// ========================================================================
//     PARAMETERS
// ========================================================================

@description('The Azure region to create the resource in')
param location string

@description('The name of the resource')
param name string

@description('The tags to associate with the resource')
param tags object

/*
** Dependencies
*/
@description('The name of the managed identity for this service')
param managedIdentityName string

@description('The ID of the subnet to link, or blank if not required')
param subnetResourceId string = ''

/*
** Service settings
*/
@description('A list of containers to apply to the container instance.')
param containers object[]

@description('The name of the Azure Container group resource to create.')
param containerGroupName string = '${name}-container-group'

@description('The behavior of Azure runtime if container has stopped.')
@allowed([ 'Always', 'Never', 'OnFailure' ])
param restartPolicy string = 'OnFailure'

// ========================================================================
//     VARIABLES
// ========================================================================

var actualContainers = map(containers, c => union(c, { 
  resources: { 
    request: { 
      cpuCores: 2
      memoryInGB: 4 
    }
  }
}))

// ========================================================================
//     AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    osType: 'Linux'
    restartPolicy: restartPolicy
    sku: 'Standard'

    // Link into devops subnet, if using a virtual network
    subnetIds: !empty(subnetResourceId) ? [
      { id: subnetResourceId }
    ] : []

    // IP address is either public or private.  Use private
    // when using a virtual network.
    ipAddress: {
      ports: [
        { port: 22, protocol: 'TCP' } // SSH
      ]
      type: !empty(subnetResourceId) ? 'Private' : 'Public'
    }
    containers: actualContainers
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output container_group_name string = containerGroup.name
output container_name string = containerGroup.properties.containers[0].name
output container_dns_name string = containerGroup.properties.ipAddress.dnsNameLabel
output container_ip_address string = containerGroup.properties.ipAddress.ip
