targetScope = 'resourceGroup'

/*
** Core Resource Template
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Core resource templates will create the resources requested, along with
** appropriate diagnostics and linkage into a virtual network.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('If using network isolation, the network isolation settings to use.')
param diagnosticSettings DiagnosticSettings?

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of a user-assigned managed identity to use as the identity for this resource.  Use a blank string for a system-assigned identity.')
param managedIdentityId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

// ========================================================================
// AZURE RESOURCES
// ========================================================================

// TODO: Create the resource

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: // TODO: Set scope to created resource
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'allLogs'
        enabled: diagnosticSettings!.enableLogs
        retentionPolicy: { days: diagnosticSettings!.logRetentionInDays, enabled: true }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
        retentionPolicy: { days: diagnosticSettings!.metricRetentionInDays, enabled: true }
      }
    ]
  }
}

// TODO: Create the network isolation resources

// ========================================================================
// OUTPUTS
// ========================================================================

// TODO: Output the ID & name of the resource

// TODO: Decide on any additional outputs that are required.
