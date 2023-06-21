#Requires -Version 7.0

<#
.SYNOPSIS
    Used to create SQL Account for a managed identity
.DESCRIPTION
    Creates a new SQL Account for the Managed Identity service principal and grants account db_

    NOTE: This script is not intended to be run from a local environment.
    This script is run by azd during devOps deployment.

    This script provides a workflow to automatically configure the deployed Azure resources and make it easier to get
    started. It is not intended as part of a recommended best practice as we do not recommend deploying Azure SQL
    with network configurations that would allow a deployment script such as this to connect.

    We recommend handling this one-time process as part of your SQL data migration process. More details can be found in our docs for Azure SQL server
    https://learn.microsoft.com/en-us/azure/app-service/tutorial-connect-msi-sql-database?tabs=windowsclient%2Cef%2Cdotnet

    Assumes the service principal that will connect to SQL has been set as the Azure AD Admin. This was handled by the bicep templates
    see https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?view=azuresql&tabs=azure-powershell#azure-portal
.PARAMETER ServerName
    A required parameter for the name of target Azure SQL Server.
.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.
.PARAMETER ServerUri
    A required parameter for the Uri of target Azure SQL Server.
.PARAMETER CatalogName
    A required parameter for the name the Azure SQL Database name used.
.PARAMETER ApplicationId
    A required parameter for the Managed Identity's Application ID used to generate its SID 
    used for creating a user in SQL.
.PARAMETER ManagedIdentityName
    A required parameter for the name of Managed Identity that will be used.
.PARAMETER SqlAdminUsername
    A required parameter for the SQL Administrator Login used.
.PARAMETER SqlAdminPassword
    A required parameter for the SQL Administrator Password used.
#>

Param(
  [Parameter(Mandatory = $true)][string]$ServerName,
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $true)][string]$ServerUri,
  [Parameter(Mandatory = $true)][string]$CatalogName,
  [Parameter(Mandatory = $true)][string]$ApplicationId,
  [Parameter(Mandatory = $true)][string]$ManagedIdentityName,
  [Parameter(Mandatory = $true)][string]$SqlAdminUsername,
  [Parameter(Mandatory = $true)][string]$SqlAdminPassword
)

Install-Module -Name SqlServer -Force
Import-Module SqlServer

# Convert the ApplicationId into a SID
[guid]$guid = [System.Guid]::Parse($ApplicationId)
foreach ($byte in $guid.ToByteArray()) {
    $byteGuid += [System.String]::Format("{0:X2}", $byte)
}
$Sid = "0x" + $byteGuid

# Create the SQL user for the managed identity and assign the db_datareader and db_datawriter roles
$CreateUserSQL = @"
    IF NOT EXISTS (
        SELECT * FROM sys.database_principals WHERE name = N'$ManagedIdentityName'
    ) 
    CREATE USER [$ManagedIdentityName] WITH sid = $Sid, type = E;

    IF NOT EXISTS (
        SELECT * FROM sys.database_principals p 
        JOIN sys.database_role_members db_datareader_role ON db_datareader_role.member_principal_id = p.principal_id 
        JOIN sys.database_principals role_names ON role_names.principal_id = db_datareader_role.role_principal_id AND role_names.[name] = 'db_datareader' 
        WHERE p.[name]=N'$ManagedIdentityName'
    ) 
    ALTER ROLE db_datareader ADD MEMBER [$ManagedIdentityName];

    IF NOT EXISTS (
        SELECT * FROM sys.database_principals p 
        JOIN sys.database_role_members db_datawriter_role ON db_datawriter_role.member_principal_id = p.principal_id 
        JOIN sys.database_principals role_names ON role_names.principal_id = db_datawriter_role.role_principal_id AND role_names.[name] = 'db_datawriter' 
        WHERE p.[name]=N'$ManagedIdentityName'
    ) 
    ALTER ROLE db_datawriter ADD MEMBER [$ManagedIdentityName];
"@
Invoke-SqlCmd -Verbose -ServerInstance $ServerUri -Database $CatalogName -Username $SqlAdminUsername -Password $SqlAdminPassword -Query $CreateUserSQL