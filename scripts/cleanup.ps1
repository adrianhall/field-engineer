<#
.SYNOPSIS
    Cleans up the project by removing the infrastructure and environment artifacts
#>

$azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable

$environmentName = $azdConfig['AZURE_ENV_NAME']
$environmentType = $azdConfig['AZURE_ENV_TYPE'] ?? 'dev'
$location = $azdConfig['AZURE_LOCATION']
$deployHubNetwork = $azdConfig['DEPLOY_HUB_NETWORK']
$networkIsolation = $azdConfig['NETWORK_ISOLATION']

if ($networkIsolation -eq 'auto') {
    $networkIsolation = $environmentType -eq 'prod' ? 'true' : 'false'
}

if ($deployHubNetwork -eq 'auto') {
    $deployHubNetwork = $networkIsolation -eq 'true' -and $environmentType -ne 'prod' ? 'true' : 'false'
}

$rgPrefix = "rg-$environmentName-$environmentType-$location"

$workloadResourceGroup = "$rgPrefix-workload"
$spokeResourceGroup = "$rgPrefix-spoke"
$hubResourceGroup = "$rgPrefix-hub"

function Remove-DiagnosticSettingsForResourceGroup($resourceGroup) {
    "===> Deleting diagnostic settings for resources in $resourceGroup" | Write-Output
    Get-AzResource -ResourceGroupName $resourceGroup
    | Foreach-Object {
        $resourceName = $_.Name
        $resourceId = $_.ResourceId
        Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction SilentlyContinue | Foreach-Object {
            "`tRemoving diagnostic settings for $resourceName" | Write-Output
            Remove-AzDiagnosticSetting -ResourceId $resourceId -Name $_.Name 
        }
    }
}

"===> Cleaning up environment $rgPrefix" | Write-Output
"`tWorkload resource group: $workloadResourceGroup" | Write-Output
if ($networkIsolation -eq 'true') {
    "`tSpoke resource group: $spokeResourceGroup" | Write-Output
}
if ($deployHubNetwork -eq 'true') {
    "`tHub resource group: $hubResourceGroup" | Write-Output
}

# Delete the private endpoints first.
if ($networkIsolation -eq 'true') {
    "===> Deleting private endpoints" | Write-Output
    Get-AzPrivateEndpoint
    | Where-Object { $_.ResourceGroupName -eq $spokeResourceGroup -or $_.ResourceGroupName -eq $hubResourceGroup -or $_.ResourceGroupName -eq $workloadResourceGroup }
    | Foreach-Object {
        "`tRemoving $($_.Name)" | Write-Output
        Remove-AzPrivateEndpoint -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force
    }
}

# Delete the budget
"===> Deleting budget(s) for workload" | Write-Output
Get-AzConsumptionBudget -ResourceGroupName $workloadResourceGroup
| Foreach-Object {
    "`tRemoving $($_.Name)" | Write-Output
    Remove-AzConsumptionBudget -Name $_.Name -ResourceGroupName $_.ResourceGroupName
}

# Delete the diagnostic settings for the workload
Remove-DiagnosticSettingsForResourceGroup -ResourceGroup $workloadResourceGroup

# Delete the workload resource group
"===> Deleting resource group $workloadResourceGroup" | Write-Output
Remove-AzResourceGroup -Name $workloadResourceGroup -Force

if ($networkIsolation -eq 'true') {
    # Delete the diagnostic settings for the spoke
    Remove-DiagnosticSettingsForResourceGroup -ResourceGroup $spokeResourceGroup

    # Delete the spoke VNET (otherwise, we have a timing issue with NSGs)
    "===> Deleting spoke VNET" | Write-Output
    Get-AzVirtualNetwork -ResourceGroupName $spokeResourceGroup | Foreach-Object {
        "`tRemoving $($_.Name)" | Write-Output
        Remove-AzVirtualNetwork -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force
    }

    # Delete the spoke resource group
    "===> Deleting resource group $spokeResourceGroup" | Write-Output
    Remove-AzResourceGroup -Name $spokeResourceGroup -Force
}

if ($deployHubNetwork -eq 'true') {
    # Delete the budget
    "===> Deleting budget(s) for hub" | Write-Output
    Get-AzConsumptionBudget -ResourceGroupName $hubResourceGroup
    | Foreach-Object {
        "`tRemoving $($_.Name)" | Write-Output
        Remove-AzConsumptionBudget -Name $_.Name -ResourceGroupName $_.ResourceGroupName
    }

    # Delete the diagnostic settings for the hub
    Remove-DiagnosticSettingsForResourceGroup -ResourceGroup $hubResourceGroup

    # Delete the hub resource group
    "===> Deleting resource group $hubResourceGroup" | Write-Output
    Remove-AzResourceGroup -Name $hubResourceGroup -Force
}


"===> Removing .azure directory" | Write-Output
Remove-Item -Recurse -Force -Path .\.azure

"`n`nComplete!  Ensure you create a new azd environment before attempting to re-deploy.`n`n" | Write-Output
