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

# TODO: Step 1: Grab the data from the azure developer CLI and convert to objects

# TODO: Step 2: Build and ZIP up the deployment-scripts Function App

# TODO: Step 3: Use Publish-AzWebapp to deploy the Function App

# TODO: Step 4: Retrieve the Function App endpoint and server key using Azure PowerShell

# TODO: Step 5: Invoke-RestMethod on Function App /api/hello to test the connection - repeat with 30 second delay for up to 15 minutes

# TODO: Step 6: For each app configuration not private, call /api/appconfig with key/value/secret and check success

# TODO: Step 7: For each managed identity, call /api/sqlrole with appropriate information

# TODO: If there are no errors, exit(0).  Otherwise, exit(1)