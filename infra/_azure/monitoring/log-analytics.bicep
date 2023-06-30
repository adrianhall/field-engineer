// ========================================================================
// PARAMETERS
// ========================================================================

@description('The Azure region to deploy this resource into.')
param location string

@description('The name of the main resource to deploy.')
param name string

@description('The tags to associate with the resource.')
param tags object = {}

/*
** Settings
*/
@allowed([ 'PerGB2018', 'PerNode', 'Premium', 'Standalone', 'Standard' ])
@description('The name of the pricing SKU to choose.')
param sku string = 'PerGB2018'

@minValue(0)
@description('The workspace daily quota for ingestion.  Use 0 for unlimited.')
param dailyQuotaInGB int = 0

// ========================================================================
// VARIABLES
// ========================================================================

var skuProperties = {
  sku: {
    name: sku
  }
}
var quotaProperties = dailyQuotaInGB > 0 ? { dailyQuotaGb: dailyQuotaInGB } : {}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource createdResource 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: union(skuProperties, quotaProperties)
}

// ========================================================================
// VARIABLES
// ========================================================================

output id string = createdResource.id
output name string = createdResource.name
