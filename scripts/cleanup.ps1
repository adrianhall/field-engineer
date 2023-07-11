<#
.SYNOPSIS
    Cleans up the Azure resources for the Field Engineer application for a given azd environment.
.DESCRIPTION
    There are times that azd down doesn't work well.  At time of writing, this includes complex
    environments with multiple resource groups and networking.  To remedy this, this script removes
    the Azure resources in the correct order.

    If you do not provide any parameters, this script will clean up the most current azd environment.
.PARAMETER Prefix
    The prefix of the Azure environment to clean up.  Provide this OR the ResourceGroup parameter to
    clean up a specific environment.
.PARAMETER ResourceGroup
    The name of the workload resource group to clean up.  Provide this OR the Prefix parameter to clean
    up a specific environment.
.PARAMETER SpokeResourceGroup
    If you provide the ResourceGroup parameter and are using network isolation, then you must also provide
    the SpokeResourceGroup if it is a different resource group.  If you don't, then the spoke network will
    not be cleaned up.
.PARAMETER HubResourceGroup
    If you provide the ResourceGroup parameter and have deployed a hub network, then you must also provide
    the HubResourceGroup if it is a different resource group.  If you don't, then the hub network will not
    be cleaned up.
#>

Param(
    [Parameter(Mandatory = $false)][string]$Prefix,
    [Parameter(Mandatory = $false)][string]$ResourceGroup,
    [Parameter(Mandatory = $false)][string]$SpokeResourceGroup,
    [Parameter(Mandatory = $false)][string]$HubResourceGroup
)

# Default Settings
$CleanupAzureDirectory = $false
$rgPrefix = ""
$rgWorkload = ""
$rgSpoke = ""
$rgHub = ""

if ($Prefix) {
    $rgPrefix = $Prefix
    $rgWorkload = "$rgPrefix-workload"
    $rgSpoke = "$rgPrefix-spoke"
    $rgHub = "$rgPrefix-hub"
} else {
    if (!$ResourceGroup) {
        if (!(Test-Path -Path ./.azure -PathType Container)) {
            "No .azure directory found and no resource group information provided - cannot clean up"
            exit 1
        }
        $azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable
        $environmentName = $azdConfig['AZURE_ENV_NAME']
        $environmentType = $azdConfig['AZURE_ENV_TYPE'] ?? 'dev'
        $location = $azdConfig['AZURE_LOCATION']
        $rgPrefix = "rg-$environmentName-$environmentType-$location"
        $rgWorkload = "$rgPrefix-workload"
        $rgSpoke = "$rgPrefix-spoke"
        $rgHub = "$rgPrefix-hub"
        $CleanupAzureDirectory = $true
    } else {
        $rgWorkload = $ResourceGroup
        $rgPrefix = $resourceGroup.Substring(0, $resourceGroup.IndexOf('-workload'))
    }
}

if ($SpokeResourceGroup) {
    $rgSpoke = $SpokeResourceGroup
} elseif ($rgSpoke -eq '') {
    $rgSpoke = "$rgPrefix-spoke"
}
if ($HubResourceGroup) {
    $rgHub = $HubResourceGroup
} elseif ($rgHub -eq '') {
    $rgHub = "$rgPrefix-hub"
}

function Test-ResourceGroupExists($resourceGroupName) {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    return $null -ne $resourceGroup
}

function Remove-ConsumptionBudgetForResourceGroup($resourceGroupName) {
    Get-AzConsumptionBudget -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        "`tRemoving $resourceGroupName::$($_.Name)" | Write-Output
        Remove-AzConsumptionBudget -Name $_.Name -ResourceGroupName $_.ResourceGroupName
    }
}

function Remove-DiagnosticSettingsForResourceGroup($resourceGroupName) {
    Get-AzResource -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        $resourceName = $_.Name
        $resourceId = $_.ResourceId
        Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction SilentlyContinue | Foreach-Object {
            "`tRemoving $resourceGroupName::$resourceName::$($_.Name)" | Write-Output
            Remove-AzDiagnosticSetting -ResourceId $resourceId -Name $_.Name 
        }
    }
}

function Remove-PrivateEndpointsForResourceGroup($resourceGroupName) {
    Get-AzPrivateEndpoint -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        "`tRemoving $resourceGroupName::$($_.Name)" | Write-Output
        Remove-AzPrivateEndpoint -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force
    }
}

"`nCleaning up environment for working $ResourceGroup" | Write-Output

# Get the list of resource groups to deal with
$resourceGroups = [System.Collections.ArrayList]@()
if (Test-ResourceGroupExists -ResourceGroupName $rgWorkload) {
    "`tFound workload resource group: $rgWorkload" | Write-Output
    $resourceGroups.Add($rgWorkload)
}
if (Test-ResourceGroupExists -ResourceGroupName $rgSpoke) {
    "`tFound spoke resource group: $rgSpoke" | Write-Output
    $resourceGroups.Add($rgSpoke)
}
if (Test-ResourceGroupExists -ResourceGroupName $rgHub) {
    "`tFound hub resource group: $rgHub" | Write-Output
    $resourceGroups.Add($rgHub)
}

"`nRemoving resources from resource groups..." | Write-Output
"> Private Endpoints:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-PrivateEndpointsForResourceGroup -ResourceGroupName $resourceGroupName
}

"> Budgets:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-ConsumptionBudgetForResourceGroup -ResourceGroupName $resourceGroupName
}

"> Diagnostic Settings:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-DiagnosticSettingsForResourceGroup -ResourceGroupName $resourceGroupName
}

"`nRemoving resource groups in order..." | Write-Output
if (Test-ResourceGroupExists -ResourceGroupName $rgWorkload) {
    "`tRemoving $rgWorkload" | Write-Output
    Remove-AzResourceGroup -Name $rgWorkload -Force
}
if (Test-ResourceGroupExists -ResourceGroupName $rgSpoke) {
    "`tRemoving $rgSpoke" | Write-Output
    Remove-AzResourceGroup -Name $rgSpoke -Force
}
if (Test-ResourceGroupExists -resourceGroupName $rgHub) {
    "`tRemoving $rgHub" | Write-Output
    Remove-AzResourceGroup -Name $rgHub -Force
}

if ($CleanupAzureDirectory -eq $true -and (Test-Path -Path ./.azure -PathType Container)) {
    "Cleaning up Azure Developer CLI state files." | Write-Output
    Remove-Item -Path ./.azure -Recurse -Force
}

"`nCleanup complete." | Write-Output
