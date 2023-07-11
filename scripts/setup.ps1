<#
.SYNOPSIS
    Sets the deployment up with one command.  This tries to be smart about
    what you want and does the provisioning and deployment steps in one
    command.
.DESCRIPTION
    When installing the Field Engineer, you have to make many choices - are
    you running in network isolation mode?  Do you need a hub?  Would you like
    to save money by deploying with a common app service plan?  This script
    will prompt you for these choices and then deploy the infrastructure for
    you.
.PARAMETER CommonAppServicePlan
    If included, deploy a common app service plan.
.PARAMETER NoCommonAppServicePlan
    If included, do not deploy a common app service plan.
.PARAMETER Hub
    If included, deploy a hub network.  No effect if not using network isolation
.PARAMETER NoHub
    If included, do not deploy a hub network.
.PARAMETER Isolated
    If included, isolate the application in a VNET.
.PARAMETER NotIsolated
    If included, do not isolate the application in a VNET.
.PARAMETER Name
    The environment name to use.
.PARAMETER Production
    If included, use production settings.
.PARAMETER Development
    If included, use development settings.
.PARAMETER NoPrompt
    If included, do not prompt for any information.  This will use the default
    settings for all options. 
#>

Param(
    [switch]$CommonAppServicePlan,
    [switch]$NoCommonAppServicePlan,
    [switch]$Hub,
    [switch]$NoHub,
    [switch]$Isolated,
    [switch]$NotIsolated,
    [string]$Name = "",
    [switch]$Production,
    [switch]$Development,
    [switch]$NoPrompt
)

function FormatMenu {
    param([array]$items, [int]$position)

    for ($i = 0 ; $i -le $items.Length; $i++) {
        $item = $items[$i]
        if ($i -eq $position) {
            Write-Host "> $($item)" -ForegroundColor Green
        } else {
            Write-Host "  $($item)"
        }
    }
}

function ShowMenu {
    param([string]$title, [array]$keys, [array]$items, [string]$defaultValue)

    $vkeycode = 0
    $pos = [array]::FindIndex($keys, [Predicate[string]] { param($s) $s -eq $defaultValue })
    $startPos = [System.Console]::CursorTop
    if ($items.Length -gt 0) {
        try {
            [System.Console]::CursorVisible = $false
            FormatMenu -items $items -position $pos
            while ($vkeycode -ne 13 -and $vkeycode -ne 27) {
                $press = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                $vkeycode = $press.VirtualKeyCode
                if ($vkeycode -eq 27) {
                    Write-Host "`nERROR: Escape pressed; aborting setup" -ForegroundColor Red
                    [System.Console]::CursorVisible = $true
                    [System.Environment]::Exit(1)
                }
                if ($vkeycode -eq 35) {
                    $pos = $items.Length - 1
                }
                if ($vkeycode -eq 36) {
                    $pos = 0
                }
                if ($vkeycode -eq 38 -or $press.Character -eq 'k') {
                    $pos--
                }
                if ($vkeycode -eq 40 -or $press.Character -eq 'j') {
                    $pos++
                }

                if ($pos -lt 0) {
                    $pos = 0
                }
                if ($pos -ge $items.Length) {
                    $pos = $items.Length - 1
                }

                [System.Console]::SetCursorPosition(0, $startPos)
                FormatMenu -items $items -position $pos
            }
        }
        finally {
            $yPos = $startPos + $items.Length
            if ($yPos -ge $Host.UI.RawUI.BufferSize.Height) {
                Clear-Host
            } else {
                [System.Console]::SetCursorPosition(0, $yPos)
            }
            [System.Console]::CursorVisible = $true
        }
    }
    else {
        Write-Host "`nERROR: No items provided for question; aborting setup" -ForegroundColor Red
        [System.Console]::CursorVisible = $true
        [System.Environment]::Exit(1)
    }

    return $keys[$pos]
}

if ($CommonAppServicePlan -and $NoCommonAppServicePlan) {
    "You cannot specify both -CommonAppServicePlan and -NoCommonAppServicePlan"
    exit 1
}

if ($Hub -and $NoHub) {
    "You cannot specify both -Hub and -NoHub"
    exit 1
}

if ($Isolated -and $NotIsolated) {
    "You cannot specify both -Isolated and -NotIsolated"
    exit 1
}

if ($Production -and $Development) {
    "You cannot specify both -Production and -Development"
    exit 1
}

Write-Host "Field Engineer Application Setup" -ForegroundColor Yellow -BackgroundColor Black

$currentDate = Get-Date -Format "yyyyMMddHHmm"
$defaultName = "fe-$currentDate"
$environmentName = $defaultName
$truefalse = @("true", "false")
if ($Name -ne "") {
    $environmentName = $Name
} elseif (!$NoPrompt) {
    $environmentName = Read-Host -Prompt "`nWhat should the environment name be? [default: $defaultName]"
    if ($environmentName -eq "") {
        $environmentName = $defaultName
    }
}

$environmentType = "dev"
if ($Development) {
    $environmentType = "dev"
} elseif ($Production) {
    $environmentType = "prod"
} elseif (!$NoPrompt) {
    Write-Host "`nWhat environment stage are you deploying?"
    $items = @( "Development", "Production" )
    $environmentType = ShowMenu -keys @( "dev", "prod") -items $items -defaultValue $environmentType
}

$networkIsolation = $environmentType -eq "prod"
if ($Isolated) {
    $networkIsolation = $true
} elseif ($NotIsolated) {
    $networkIsolation = $false
} elseif (!$NoPrompt) {
    Write-Host "`nDo you want the environment to be network isolated (in a VNET)?"
    $items = @( "Yes - use network isolation", "No - do not use network isolation" )
    $isIsolated = ShowMenu -keys $truefalse -items $items -defaultValue $(if ($networkIsolation -eq $true) { "true" } else { "false" })
    $networkIsolation = $isIsolated -eq "true"
}

$deployHubNetwork = $networkIsolation -eq $true -and $environmentType -eq "dev"
if ($networkIsolation) {
    if ($Hub) {
        $deployHubNetwork = $true
    } elseif ($NoHub) {
        $deployHubNetwork = $false
    } elseif (!$NoPrompt) {
        Write-Host "`nDo you want to deploy a hub network with an Azure Firewall, Bastion, and Jump host?"
        $items = @( "Yes - deploy a hub network", "No - do not deploy a hub network" )
        $useHub = ShowMenu -keys $truefalse -items $items -defaultValue $(if ($deployHubNetwork -eq $true) { "true" } else { "false" })
        $deployHubNetwork = $useHub -eq "true"
    }
}

$casp = $environmentType -eq "dev"
if ($CommonAppServicePlan) {
    $casp = $true
} elseif ($NoCommonAppServicePlan) {
    $casp = $false
} elseif (!$NoPrompt) {
    Write-Host "`nDo you want to use a common App Service Plan for all App Services?"
    $items = @( "Use a common App Service Plan for all App Services", "Use a dedicated App Service Plan for each App Service" )
    $sCasp = ShowMenu -keys $truefalse -items $items -defaultValue $(if ($casp -eq $true) { "true" } else { "false" })
    $casp = $sCasp -eq "true"
}

Write-Host "`nProposed settings:" -ForegroundColor Yellow
Write-Host "`tEnvironment name: $environmentName"
Write-Host "`tEnvironment type: $environmentType"
Write-Host "`tNetwork isolation: $networkIsolation"
Write-Host "`tDeploy hub network: $deployHubNetwork"
Write-Host "`tUse common App Service Plan: $casp"

if (!$NoPrompt) {
    Write-Host "`nDo you want to proceed with the deployment?"
    $items = @("Continue to deployment.", "Cancel deployment.")
    $q = ShowMenu -keys $truefalse -items $items -defaultValue "false"
    if ($q -eq "false") {
        exit 0
    }
}

azd env new $environmentName
azd env set AZURE_ENV_TYPE $environmentType
azd env set NETWORK_ISOLATION $(if ($networkIsolation) { "true" } else { "false" })
azd env set DEPLOY_HUB_NETWORK $(if ($networkIsolation) { "true" } else { "false" })
azd env set COMMON_APP_SERVICE_PLAN $(if ($networkIsolation) { "true" } else { "false" })

if ($NoPrompt) {
    azd provision --no-prompt
} else {
    azd provision
}
