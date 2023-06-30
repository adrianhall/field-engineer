<#
.SYNOPSIS
    Cleans up the project by removing the infrastructure and environment artifacts
#>

$azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable

$environmentName = $azdConfig['AZURE_ENV_NAME']

Get-AzResourceGroup
    | Where-Object { $_.ResourceGroupName -like "rg-$environmentName-*" }
    | Foreach-Object { 
        "Removing $($_.ResourceGroupName)" | Write-Output
        Remove-AzResourceGroup -Name $_.ResourceGroupName -Force -AsJob -Verbose
    }

"Removing .azure directory" | Write-Output
Remove-Item -Recurse -Force -Path .\.azure
