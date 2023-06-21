#Requires -Version 7.0

<#
.SYNOPSIS
    Sets a key-value setting in the App Configuration store.
.DESCRIPTION
    Creates or updates a key-value setting in the App Configuration store.
.PARAMETER AppConfigurationUri
    The URI of the App Configuration store.
.PARAMETER Key
    The key of the setting to set within the App Configuration store.
.PARAMETER Value
    The base64-encoded value of the setting to set within the App Configuration store.
.PARAMETER isSecret
    If 'true', then this is a secret and the value is a URI to the secret.
#>

Param(
    [Parameter(Mandatory = $true)] [string] $AppConfigurationUri,
    [Parameter(Mandatory = $true)] [string] $Key,
    [Parameter(Mandatory = $true)] [string] $Value,
    [Parameter(Mandatory = $true)] [string] $Secret
)

@"
set-appconfig-setting.ps1 arguments:
    AppConfigurationUri: $AppConfigurationUri
    Key: $Key
    Value: $Value
    isSecret: $Secret
"@ | Write-Output

$apiVersion = '?api-version=1.0'
$token = (Get-AzAccessToken -ResourceUrl $AppConfigurationUri).Token
$value = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))

$body = @{
    value = $value
    content_type = "text/plain"
}
if ($Secret -eq 'true') {
    $body = @{
        value = "{""uri"":""$value""}"
        content_type = "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8"
    }
}

$params = @{
    body = $body | ConvertTo-Json -Depth 9
    ContentType = "application/vnd.microsoft.appconfig.kv+json;charset=utf-8"
    Headers = @{ Authorization = "Bearer $token" }
    Method = "PUT"
    StatusCodeVariable = "httpStatusCode"
    Uri = "$AppConfigurationUri/kv/$Key$apiVersion"
}

"Running Invoke-RestMethod with the following parameters:" | Write-Output
$params | ConvertTo-Json -Depth 9 | Write-Output

$response = Invoke-RestMethod @params

"Response is $httpStatusCode" | Write-Output
$response | ConvertTo-Json -Depth 9 | Write-Output

# Exit with non-zero exit code if we failed
if ($httpStatusCode -gt 299) {
    [System.Environment]::Exit(1)
}
