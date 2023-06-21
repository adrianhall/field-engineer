targetScope = 'subscription'

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

/*
** Parameters provided by the Azure Developer CLI - these should always be available.
*/
@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@allowed([ 'dev', 'prod' ])
@description('The type of environment to deploy.  This is used to size the resources appropriately.')
param environmentType string = 'dev'

@minLength(3)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2`.')
param location string

@description('The running user/service principal')
param principalId string = ''

/*
** Additional (optional) parameters to configure the infrastructure of the application.
*/
@allowed([ 'true', 'false' ])
@description('If \'true\', then the application is being deployed during a workshop.  Certain resources will be common (e.g. the SQL server)')
param isWorkshop string = 'false'

@allowed([ 'isolated', 'off', 'auto' ])
@description('The network isolation mode for this application; set to \'isolated\' to use isolated routing via private links and a virtual network.  \'auto\' uses isolation in production, but not in development.')
param networkIsolation string = 'auto'

@minLength(3)
@description('The email address of the owner of the application; this is used for tagging.')
param ownerEmail string = 'noreply@contoso.com'

@minLength(3)
@description('The name of the owner of the application; this is used for tagging.')
param ownerName string = 'not specified'

@secure()
@minLength(8)
@description('The SQL Administrator password; if not provided, a random password will be generated.')
param sqlAdministratorPassword string = newGuid()

@minLength(8)
@description('The SQL Administrator username to use; if not provided, \'appadmin\' will be used.')
param sqlAdministratorUsername string = 'appadmin'

@allowed([ 'true', 'false', 'auto' ])
@description('If \'true\', use a common app service plan.  If \'false\', separate app service plans will be used for each app service.  If \'auto\', a common app service plan is used in development.')
param useCommonAppServicePlan string = 'auto'

/*
** You can manually name the resources that we create by setting one of the following parameters in
** the main.parameters.json file.  Use a blank string to have the name generated.
*/
param apiAppServiceName string = ''
param apiAppServicePlanName string = ''
param apiManagedIdentityName string = ''
param apiManagementName string = ''
param appConfigurationName string = ''
param applicationInsightsName string = ''
param applicationOwnerManagedIdentityName string = ''
param commonAppServicePlanName string = ''
param dashboardName string = ''
param frontDoorEndpointName string = ''
param frontDoorProfileName string = ''
param keyVaultName string = ''
param logAnalyticsWorkspaceName string = ''
param resourceGroupName string = ''
param sqlDatabaseName string = ''
param sqlServerName string = ''
param virtualNetworkName string = ''
param webApplicationFirewallName string = ''
param webAppServiceName string = ''
param webAppServicePlanName string = ''
param webManagedIdentityName string = ''

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var resourceToken = uniqueString(subscription().subscriptionId, environmentName, environmentType, location)

var tags = {
  'azd-env-name': environmentName
  'azd-env-type': environmentType
  'azd-owner-email': ownerEmail
  'azd-owner-name': ownerName
}

var isProduction = startsWith(environmentType, 'prod')

/*
** The environment provides shared information about the environment to produce.
*/
var environment = {
  name: environmentName
  isProduction: isProduction
  isNetworkIsolated: networkIsolation == 'isolated' || (networkIsolation == 'auto' && isProduction)
  location: location
  principalId: isProduction ? '' : principalId
  resourceToken: resourceToken
  tags: tags
  useCommonAppServicePlan: useCommonAppServicePlan == 'true' || (useCommonAppServicePlan == 'auto' && !isProduction)
  useExistingSqlServer: isWorkshop == 'true' && !empty(sqlServerName)
}

/*
** We pre-generate all resource names here to simplify the service definitions.
*/
var resourceNames = {
  apiAppService: !empty(apiAppServiceName) ? apiAppServiceName : 'apiapp-${resourceToken}'
  apiAppServicePlan: !empty(apiAppServicePlanName) ? apiAppServicePlanName : 'asp-api-${resourceToken}'
  apiManagedIdentity: !empty(apiManagedIdentityName) ? apiManagedIdentityName : 'mi-api-${resourceToken}'
  apiManagement: !empty(apiManagementName) ? apiManagementName : 'apim-${resourceToken}'
  appConfiguration: !empty(appConfigurationName) ? appConfigurationName : 'appconfig-${resourceToken}'
  applicationInsights: !empty(applicationInsightsName) ? applicationInsightsName : 'appinsights-${resourceToken}'
  applicationInsightsDashboard: !empty(dashboardName) ? dashboardName : 'dashboard-${resourceToken}'
  applicationOwnerManagedIdentity: !empty(applicationOwnerManagedIdentityName) ? applicationOwnerManagedIdentityName : 'mi-appowner-${resourceToken}'
  commonAppServicePlan: !empty(commonAppServicePlanName) ? commonAppServicePlanName : 'asp-common-${resourceToken}'
  frontDoorEndpoint: !empty(frontDoorEndpointName) ? frontDoorEndpointName : 'afd-${resourceToken}'
  frontDoorProfile: !empty(frontDoorProfileName) ? frontDoorProfileName : 'afd-profile-${resourceToken}'
  keyVault: !empty(keyVaultName) ? keyVaultName : 'kv-${resourceToken}'
  logAnalyticsWorkspace: !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : 'workspace-${resourceToken}'
  sqlDatabase: !empty(sqlDatabaseName) ? sqlDatabaseName : 'fieldengineer-${resourceToken}'
  sqlServer: !empty(sqlServerName) ? sqlServerName : 'dbhost-${resourceToken}'
  virtualNetworkName: !empty(virtualNetworkName) ? virtualNetworkName : 'vnet-${resourceToken}'
  webApplicationFirewall: !empty(webApplicationFirewallName) ? webApplicationFirewallName : 'waf${resourceToken}'
  webAppService: !empty(webAppServiceName) ? webAppServiceName : 'webapp-${resourceToken}'
  webAppServicePlan: !empty(webAppServicePlanName) ? webAppServicePlanName : 'asp-web-${resourceToken}'
  webManagedIdentity: !empty(webManagedIdentityName) ? webManagedIdentityName : 'mi-web-${resourceToken}'
}

// =====================================================================================================================
//     INFRASTRUCTURE MODULES
// =====================================================================================================================

/*
** The common resource group - all resources for the application are built here.
*/
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : 'rg-${environmentType}-${environmentName}-${resourceToken}'
  location: environment.location
  tags: environment.tags
}

/*
** Before we get started, we need to create the monitoring resources.  We use common monitoring
** resources and settings throughout the application.
*/
module monitoring './architecture/monitoring-resources.bicep' = {
  name: 'arch-monitoring'
  scope: rg
  params: {
    environment: environment
    
    // Resource names created by this module
    applicationInsightsName: resourceNames.applicationInsights
    applicationInsightsDashboardName: resourceNames.applicationInsightsDashboard
    logAnalyticsWorkspaceName: resourceNames.logAnalyticsWorkspace
  }
}

/*
** The rest of the resources are built by 'resources.bicep' with a resource group scope.
*/
module resources './resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    diagnosticSettings: {
      auditLogRetentionInDays: environment.isProduction ? 30 : 3
      diagnosticLogRetentionInDays: environment.isProduction ? 7 : 3
      enableAuditLogs: environment.isProduction
      enableDiagnosticLogs: true
      logAnalyticsWorkspaceName: monitoring.outputs.log_analytics_workspace_name
    }
    environment: environment
    resourceNames: resourceNames
    sqlAdministratorPassword: sqlAdministratorPassword
    sqlAdministratorUsername: sqlAdministratorUsername
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output service_api_endpoints string[] = resources.outputs.service_api_endpoints
output service_web_endpoints string[] = resources.outputs.service_web_endpoints
