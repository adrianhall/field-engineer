// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type Environment = {
  @description('The name of the Azure Developer environment - user chosen')
  name: string

  @description('If true, we are deploying a production environment.  This is used to size resources appropriately.')
  isProduction: bool

  @description('If true, we want network isolation via a virtual network and private endpoints')
  isNetworkIsolated: bool

  @description('The default region we want the resources to be created in')
  location: string

  @description('The running user/service principal; use a blank string to not use a principalId')
  principalId: string

  @description('A token that is used in generating names for resources.  This is unique to the environment and region')
  resourceToken: string

  @description('A list of default tags to apply to all resources')
  tags: object

  @description('If true, use a common app service plan; if false, create an app service plan per app service')
  useCommonAppServicePlan: bool

  @description('If true, use an existing SQL server; if false, create a new SQL server')
  useExistingSqlServer: bool
}

type DiagnosticSettings = {
  @description('The name of the Log Analytics Workspace')
  logAnalyticsWorkspaceName: string

  @description('The audit log retention policy')
  auditLogRetentionInDays: int

  @description('The diagnostic log retention policy')
  diagnosticLogRetentionInDays: int

  @description('If true, enable audit logging')
  enableAuditLogs: bool

  @description('If true, enable diagnostic logging')
  enableDiagnosticLogs: bool
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The environment we are provisioning for')
param environment Environment

/*
** Resources to potentially create
*/
@description('The name of the common App Service Plan to create')
param appServicePlanName string

@description('The name of the managed identity to create for the application owner')
param managedIdentityName string

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

module applicationOwnerIdentity '../azure/identity/managed-identity.bicep' = {
  name: 'common-appowner-identity'
  params: {
    location: environment.location
    name: managedIdentityName
    tags: environment.tags
  }
}

module appServicePlan '../azure/hosting/app-service-plan.bicep' = if (environment.useCommonAppServicePlan) {
  name: 'common-appserviceplan'
  params: {
    diagnosticSettings: diagnosticSettings
    location: environment.location
    name: appServicePlanName
    tags: environment.tags
    
    // Service settings
    autoScaleSettings: environment.isProduction ? { minimumCapacity: 2, maximumCapacity: 10 } : {}
    sku: environment.isProduction ? 'P1v3' : 'B1'
  }
}

// =====================================================================================================================
//     OUTPUTS
// =====================================================================================================================

output managed_identity_name string = applicationOwnerIdentity.outputs.name
output app_service_plan_name string = environment.useCommonAppServicePlan ? appServicePlan.outputs.name : ''

output principal_id string = applicationOwnerIdentity.outputs.principal_id
