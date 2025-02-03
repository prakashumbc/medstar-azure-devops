# PowerShell Script for Monitoring Azure Resources

# Login to Azure
Write-Host "Logging into Azure..."
az login --output none

# Define Thresholds
$cpuThreshold = 80
$memoryThreshold = 75

# Get all Virtual Machines
Write-Host "`nFetching Azure Virtual Machines..."
$vmList = az vm list --query "[].{Name:name,ResourceGroup:resourceGroup}" --output json | ConvertFrom-Json

# Loop through each VM and check CPU & Memory
foreach ($vm in $vmList) {
    Write-Host "`nChecking VM: $($vm.Name) in Resource Group: $($vm.ResourceGroup)"

    # Get CPU Usage
    $cpuUsage = az monitor metrics list --resource "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/$($vm.ResourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)" --metric "Percentage CPU" --output json | ConvertFrom-Json
    $cpuAvg = [math]::Round(($cpuUsage.value.timeseries.data.average | Measure-Object -Average).Average, 2)

    # Get Memory Usage
    $memoryUsage = az monitor metrics list --resource "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/$($vm.ResourceGroup)/providers/Microsoft.Compute/virtualMachines/$($vm.Name)" --metric "Available Memory Bytes" --output json | ConvertFrom-Json
    $memoryAvg = [math]::Round(($memoryUsage.value.timeseries.data.average | Measure-Object -Average).Average, 2)

    Write-Host "CPU Usage: $cpuAvg% | Memory Usage: $memoryAvg MB"

    # Alert if CPU or Memory exceeds threshold
    if ($cpuAvg -gt $cpuThreshold) {
        Write-Host "⚠ ALERT: High CPU Usage ($cpuAvg%) on VM: $($vm.Name)" -ForegroundColor Red
    }
    if ($memoryAvg -gt $memoryThreshold) {
        Write-Host "⚠ ALERT: High Memory Usage ($memoryAvg MB) on VM: $($vm.Name)" -ForegroundColor Yellow
    }
}

# Get Storage Account Usage
Write-Host "`nFetching Storage Account Usage..."
$storageAccounts = az storage account list --query "[].{Name:name,ResourceGroup:resourceGroup}" --output json | ConvertFrom-Json
foreach ($storage in $storageAccounts) {
    $usage = az storage account show-usage --account-name $storage.Name --output json | ConvertFrom-Json
    Write-Host "Storage Account: $($storage.Name) - Used: $($usage.currentValue)GB / $($usage.limit)GB"
}

# Get Kubernetes Cluster Pods
Write-Host "`nFetching Kubernetes Pod Status..."
$pods = az aks get-credentials --resource-group MedStar-RG --name MedStarAKSCluster --overwrite-existing
$kubePods = kubectl get pods --all-namespaces -o json | ConvertFrom-Json
foreach ($pod in $kubePods.items) {
    Write-Host "Pod: $($pod.metadata.name) | Status: $($pod.status.phase)"
    if ($pod.status.phase -ne "Running") {
        Write-Host "⚠ ALERT: Pod $($pod.metadata.name) is in $($pod.status.phase) state" -ForegroundColor Red
    }
}

# Save Logs to File
$logFile = "monitoring-log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
Write-Host "Saving logs to $logFile..."
Get-Content $logFile | Out-File -FilePath $logFile -Encoding utf8

Write-Host "`n✅ Monitoring Completed Successfully!"
