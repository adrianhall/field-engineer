<#
.SYNOPSIS
    Sets the deployment up with one command
#>

Param(
    [Parameter(Mandatory = $false)][boolean]$hub = $false,
    [Parameter(Mandatory = $false)][boolean]$net = $false,
    [Parameter(Mandatory = $false)][boolean]$prod = $false,
    [Parameter(Mandatory = $true)][string]$env
)

azd init -e $env
if ($hub -eq $true) {
    azd env set DEPLOY_HUB_NETWORK "true"
}
if ($net -eq $true -or $hub -eq $true) {
    azd env set NETWORK_ISOLATION "true"
}
if ($prod -eq $true) {
    azd env set AZURE_ENV_TYPE "prod"
}

azd provision --no-prompt
