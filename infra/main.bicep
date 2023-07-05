targetScope = 'subscription'

// ========================================================================
//
//  Field Engineer Application
//  Infrastructure description
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

/*
** Parameters that are provided by Azure Developer CLI.
**
** If you are running this with bicep, use the main.parameters.json
** and overrides to generate these.
*/

@minLength(3)
@maxLength(18)
@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@minLength(3)
@description('The email address of the owner of the workload.')
param ownerEmail string

@minLength(3)
@description('The name of the owner of the workload.')
param ownerName string

@description('The ID of the running user or service principal.  This will be set as the owner when needed.')
param principalId string = ''

@allowed([ 'ServicePrincipal', 'User' ])
@description('The type of the principal specified in \'principalId\'')
param principalType string = 'ServicePrincipal'

/*
** Passwords - you must specify these!
*/
@secure()
@minLength(8)
@description('The password for the administrator accounts.  This is used for the jump host, build agent, and SQL server.')
param administratorPassword string = newGuid()

/*
** Parameters that make changes to the deployment based on requirements.  They mostly have
** "reasonable" defaults such that a developer can just run "azd up" and get a working dev
** system.
*/

// Environment type - dev or prod; affects sizing and what else is deployed alongside.
@allowed([ 'dev', 'prod' ])
@description('The set of pricing SKUs to choose for resources.  \'dev\' uses cheaper SKUs by avoiding features that are unnecessary for writing code.')
param environmentType string = 'dev'

// Deploy Hub Resources; if auto, then
//  - environmentType == dev && networkIsolation == true => true
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy hub resources.  Normally, the hub resources are not deployed since the app developer wouldn\' have access, but we also need to be able to deploy a complete solution')
param deployHubNetwork string = 'auto'

// Jump host resources; if auto, then
//  - environmentType == dev && deployHubResources == true => private
//  - environmentType == dev && deployHubResources == false && networkIsolation == true => public
//  - environmentType == prod || networkIsolation == flase => off
@allowed([ 'auto', 'off', 'private', 'public' ])
@description('Deploy a jump host.  A jump host is a virtual machine that is available in the networking resource group with access to the VNET resources.')
param deployJumphost string = 'auto'

// Network isolation - determines if the app is deployed in a VNET or not.
//  if environmentType == prod => true
//  if environmentType == dev => false
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy the application in network isolation mode.  \'auto\' will deploy in isolation only if deploying to production.')
param networkIsolation string = 'auto'

// Common App Service Plan - determines if a common app service plan should be deployed.
//  auto = yes in dev, no in prod.
@allowed([ 'auto', 'false', 'true' ])
@description('Should we deploy a common app service plan, used by both the API and WEB app services?  \'auto\' will deploy a common app service plan in dev, but separate plans in prod.')
param useCommonAppServicePlan string = 'auto'

// ========================================================================
// VARIABLES
// ========================================================================

var prefix = '${environmentName}-${environmentType}'

// Boolean to indicate the various values for the deployment settings
var isProduction = environmentType == 'prod'
var isNetworkIsolated = networkIsolation == 'true' || (networkIsolation == 'auto' && isProduction)
var willDeployHubNetwork = isNetworkIsolated && (deployHubNetwork == 'true' || (deployHubNetwork == 'auto' && !isProduction))
var willDeployJumphost = isNetworkIsolated  && deployJumphost != 'off'
var jumphostIsPublic = willDeployJumphost && deployJumphost == 'public' || (deployJumphost == 'auto' && !willDeployHubNetwork)

var deploymentSettings = {
  deployHubNetwork: willDeployHubNetwork
  deployJumphost: networkIsolation == 'true' && (deployJumphost == 'auto' && deployHubNetwork == 'true')
  isProduction: isProduction
  isNetworkIsolated: isNetworkIsolated
  location: location
  jumphostIsPublic: jumphostIsPublic
  name: environmentName
  principalId: principalId
  principalType: principalType
  stage: environmentType
  tags: {
    'azd-env-name': environmentName
    'azd-env-type': environmentType
    'azd-owner-email': ownerEmail
    'azd-owner-name': ownerName
  }
  useCommonAppServicePlan: useCommonAppServicePlan == 'true' || (useCommonAppServicePlan == 'auto' && !isProduction)
}

var diagnosticSettings = {
  auditLogRetentionInDays: isProduction ? 30 : 3
  diagnosticLogRetentionInDays: isProduction ? 7 : 3
  enableAuditLogs: isProduction
  enableDiagnosticLogs: true
}

var networkSettings = {
  hub: {
    addressSpace: '10.1.0.0/16'
    addressPrefixes: {
      firewall:      '10.1.0.0/26'
      bastion:       '10.1.0.64/26'
    }
  }
  spoke: {
    addressSpace: '10.2.0.0/16'
    addressPrefixes: {
      apiInbound:    '10.2.0.0/25'
      apiOutbound:   '10.2.0.128/25'
      webInbound:    '10.2.1.0/25'
      webOutbound:   '10.2.1.128/25'
      configuration: '10.2.2.0/26'
      storage:       '10.2.2.64/26'
      devops:        '10.2.254.0/26'
      jumphost:      '10.2.254.64/26'
    }
  }
}

// ========================================================================
// BICEP MODULES
// ========================================================================

/*
** Every single resource can have a naming override.  Overrides should be placed
** into the 'naming.overrides.jsonc' file.  The output of this module drives the
** naming of all resources.
*/
module naming './_modules/common/naming.bicep' = {
  name: '${prefix}-naming'
  params: {
    deploymentSettings: deploymentSettings
    overrides: loadJsonContent('./naming.overrides.jsonc')
  }
}

/*
** Resources are organized into one of four resource groups:
**
**  hubResourceGroup      - contains the hub network resources
**  spokeResourceGroup    - contains the spoke network resources
**  sqlResourceGroup      - contains the SQL resources
**  workloadResourceGroup - contains the workload resources 
** 
** Not all of the resource groups are necessarily available - it
** depends on the settings.
*/
module resourceGroups './_modules/common/resource-groups.bicep' = {
  name: '${prefix}-resource-groups'
  params: {
    deploymentSettings: deploymentSettings
    resourceNames: naming.outputs.resourceNames
  }
}

/*
** Create the Azure Monitor components.  This consists of:
**
**  A log analytics workspace
**  An application insights service
**  A dashboard for the service
*/
module azureMonitor './_modules/common/azure-monitor.bicep' = {
  name: '${prefix}-monitoring'
  params: {
    deploymentSettings: deploymentSettings
    resourceGroupName: deploymentSettings.deployHubNetwork ? naming.outputs.resourceNames.hubResourceGroup : naming.outputs.resourceNames.resourceGroup
    resourceNames: naming.outputs.resourceNames
  }
  dependsOn: [
    resourceGroups
  ]
}

/*
** Create the hub network, if requested. 
**
** The hub network consists of the following resources
**
**  The hub virtual network with subnets for Bastion Hosts and Firewall
**  The bastion host
**  The firewall
**  A route table that is used within the spoke to reach the firewall
*/
module hubNetwork './_modules/networking/hub.bicep' = if (deploymentSettings.deployHubNetwork) {
  name: '${prefix}-hub-network'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    networkSettings: networkSettings.hub
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.workspace_id

    // Module specific parameters
    allowedEgressAddresses: [
      networkSettings.hub.addressSpace
      networkSettings.spoke.addressSpace
    ]
    unrestrictedEgressAddresses: [
      networkSettings.spoke.addressPrefixes.devops
      networkSettings.spoke.addressPrefixes.jumphost
    ]
  }
  dependsOn: [
    resourceGroups
    azureMonitor
  ]
}

/*
** Create the Spoke Network (if requested)
**
** The spoke network consists of a virtual network with subnets for each
** component, a set of network security groups to control access, and a
** set of private DNS zones to support the private endpoints.
*/
module spokeNetwork './_modules/networking/spoke.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: '${prefix}-spoke-network'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    networkSettings: networkSettings.spoke
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.workspace_id
    routeTableId: deploymentSettings.deployHubNetwork ? hubNetwork.outputs.route_table_id : ''
  }
  dependsOn: [
    resourceGroups
    azureMonitor
    hubNetwork
  ]
}

/*
** If we created the hub network, it's also our responsibility to peer the
** spoke network to the peer network.
*/
module peerNetworks './_modules/networking/peer-networks.bicep' = if (deploymentSettings.deployHubNetwork) {
  name: '${prefix}-peer-networks'
  params: {
    hubResourceGroupName: naming.outputs.resourceNames.hubResourceGroup
    hubVirtualNetworkName: naming.outputs.resourceNames.hubVirtualNetwork
    spokeResourceGroupName: naming.outputs.resourceNames.spokeResourceGroup
    spokeVirtualNetworkName: naming.outputs.resourceNames.spokeVirtualNetwork
  }
  dependsOn: [
    resourceGroups
    hubNetwork
    spokeNetwork
  ]
} 

/*
** Create the resources for the workload.  These will live inside the
** spoke network, if configured.
*/
module workloadResources './_modules/workload/resources.bicep' = {
  name: '${prefix}-workload-resources'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.workspace_id
    configurationSubnetId: deploymentSettings.isNetworkIsolated ? spokeNetwork.outputs.configuration_subnet_id : ''
    storageSubnetId: deploymentSettings.isNetworkIsolated ? spokeNetwork.outputs.storage_subnet_id : ''

    // Settings
    sqlAdministratorPassword: administratorPassword
    sqlAdministratorUsername: naming.outputs.resourceNames.administratorUsername
  }
}

/*
** Add a budget and other cost management resources.
*/
module costManagement './_modules/common/cost-management.bicep' = {
  name: '${prefix}-cost-management'
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames
  }
  dependsOn: [
    workloadResources
  ]
}

// ========================================================================
// OUTPUTS
// ========================================================================

