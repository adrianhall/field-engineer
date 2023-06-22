#Requires -Version 7.0

<#
.SYNOPSIS
    Handles post-provisioning tasks when using the Azure Developer CLI
.DESCRIPTION
    After the bicep provisioning task has been completed, there are still a few things to do that cannot generally
    be done because the services are not publically available when running in network isolation mode.  These include:

    * Adding key-values to the App Configuration and Key Vault services.
    * Creating managed identity accounts for the Azure SQL database and adding roles.
    * Deploying the database schema and/or running database migrations.

    To facilitate these tasks, this script is run by the Azure Developer CLI after the bicep provisioning task has
    completed.  During provisioning, we create an Azure Function App that is VNET integrated (so it has access to
    the private resources) with the following endpoints:

    * POST /api/appconfig { key, value, secret } => adds a key-value pair to the App Configuration service.
    * POST /api/keyvault { key, value } => adds a key-value pair to the Key Vault service.
    * POST /api/sqlrole { managedIdentity } => adds a database owner or user to the SQL database.

    To do this, the following values are grabbed from the Azure Developer CLI:

    * postprovision_configuration_settings => a JSON string of key-value pairs to add to the App Configuration service.
    * postprovision_managed_identities => a jSON string of managed identities to add as SQL users.
    * postprovision_settings => a JSON string with the function app name and associated service names.

    This facilitates a developer-centric but isolated workflow.  If you are doing this in a production environment, do
    not do this mechanism.  Instead, use an appropriate CI/CD workflow to do the same thing.
#>

$scriptDirectory = $MyInvocation.MyCommand.Path | Split-Path -Parent
$functionAppDirectory = Join-Path -Path $scriptDirectory -ChildPath './function-app'
$artifactsDirectory = Join-Path -Path $scriptDirectory -ChildPath './build'

# Create the artifacts directory if it doesn't exist.  Will throw an error if build is a file.
New-Item -Path $artifactsDirectory -ItemType Directory -Force

# Step 1: Grab the data from the azure developer CLI and convert to objects

@"

### Reading current Azure Developer CLI output.

"@ | Write-Output
$azdConfig = azd env get-values -o json | ConvertFrom-Json -AsHashtable
$resources = $azdConfig['postprovision_resources'] | ConvertFrom-Json -AsHashtable

$functionAppName = $resources['functionApp']
$resourceGroupName = $resources['resourceGroup']

@"
  Resource Group: $resourceGroupName
  Function App: $functionAppName
  Script directory: $scriptDirectory
  Function App location: $functionAppDirectory
  Artifacts Directory: $artifactsDirectory
"@ | Write-Output

# Step 2: Build and ZIP up the deployment-scripts Function App

@"

### Building Azure Function App and creating deployment package.

"@ | Write-Output
$functionArtifact = Join-Path -Path $artifactsDirectory -ChildPath './deploypkg.zip'
Push-Location -Path $functionAppDirectory
dotnet publish -c Release
Compress-Archive -Path * -DestinationPath $functionArtifact -Force
Pop-Location

# Step 3: Use Publish-AzWebapp to deploy the Function App

@"

### Publishing Azure Function App deployment package.

"@ | Write-Output
$functionApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionAppName
Publish-AzWebApp -ResourceGroupName $resourceGroupName -WebApp $functionApp -ArchivePath $functionArtifact -Force

# Step 4: Retrieve the Function App endpoint and server key using Azure PowerShell
$defaultHostName = $functionApp.DefaultHostName
$functionAppId = $functionApp.Id

$appconfigTrigger = "AppConfiguration"
$appconfigKey = (Invoke-AzResourceAction -ResourceId "$functionAppId/functions/$appConfigTrigger" -Action listkeys -Force).default
$appconfigUrl = "https://$DefaultHostName/api/$appconfigTrigger" + "?code=" + $appconfigKey
"App Configuration URL: $appconfigUrl" | Write-Output

$sqlroleTrigger = "SqlRole"
$sqlroleKey = (Invoke-AzResourceAction -ResourceId "$functionAppId/functions/$sqlroleTrigger" -Action listkeys -Force).default
$sqlroleUrl = "https://$DefaultHostName/api/$sqlroleTrigger" + "?code=" + $sqlroleKey
"SQL Role URL: $sqlroleUrl" | Write-Output

# TODO: Step 5: For each app configuration not private, call /api/appconfig with key/value/secret and check success

# TODO: Step 7: For each managed identity, call /api/sqlrole with appropriate information

# TODO: Step 8: Approve the private endpoints (if they exist) from Azure Front Door to the App Service

# TODO: If there are no errors, exit(0).  Otherwise, exit(1)
