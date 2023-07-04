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
@description('A list of environment variables to apply to the container instance.')
param environmentVariables ContainerEnvironmentVariable[] = []

@description('Container image to deploy. Should be of the form repoName/imagename:tag for images stored in public Docker Hub, or a fully qualified URI for other registries. Images from private registries require additional registry credentials.')
param image string = 'mcr.microsoft.com/azuredocs/aci-helloworld'

@description('The name of the Azure Container group resource to create.')
param containerGroupName string = '${name}-container-group'

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

@description('The behavior of Azure runtime if container has stopped.')
@allowed([ 'Always', 'Never', 'OnFailure' ])
param restartPolicy string = 'OnFailure'

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
    containers: [
      {
        name: name
        properties: {
          environmentVariables: environmentVariables
          image: image
          ports: [
            { port: 22, protocol: 'TCP' } // SSH
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    // TODO: Public IP Address for when not network isolated
    ipAddress: {
      ports: [
        { port: 22, protocol: 'TCP' } // SSH
      ]
      type: 'Private'
    }
    osType: 'Linux'
    restartPolicy: restartPolicy
    sku: 'Standard'
    // TODO: Public IP Address for when not network isolated
    subnetIds: [
      { id: subnetResourceId }
    ]
  }
}

// ========================================================================
//     OUTPUTS
// ========================================================================

output container_group_name string = containerGroup.name
output container_name string = containerGroup.properties.containers[0].name
output container_dns_name string = containerGroup.properties.ipAddress.dnsNameLabel
output container_ip_address string = containerGroup.properties.ipAddress.ip
