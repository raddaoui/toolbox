Param(
 [Parameter (Mandatory = $true)]
 [string]$resourceGroupName,
 [Parameter (Mandatory = $true)]
 [string]$vmName,
 [Parameter (Mandatory = $true)]
 [string]$storageAccountName,
 [Parameter (Mandatory = $true)]
 [string]$storageContainerName,
 [Parameter (Mandatory = $true)]
 [string]$storageLocation,
 [Parameter (Mandatory = $true)]
 [string]$storageResourceGroup,
 [Parameter (Mandatory = $true)]
 [string]$destinationResourceGroup
)

Write-Output "copying VM: $vmName OS disk in source Resource Group: $resourceGroupName to destination Resource Group: $destinationResourceGroup using Storage Account: $storageAccountName and container: $storageContainerName"

# connect using Run As account
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint -Subscription $Conn.SubscriptionId
Write-Output $Conn

# Provide Shared Access Signature (SAS) expiry duration in seconds e.g. 3600 to create for snapshot export
$sasExpiryDuration = "3600"

# Create snapshotname based on timestamp
$timestamp = Get-Date -Format "MM-dd-yyyy-HH-mm"
$snapshotName = "$($vmName)-snapshot-$($timestamp)"
Write-Output $snapshotName


# Name of the VHD file to which disk's snapshot will be copied in the storage account.
$destinationVHDFileName = "$($snapshotName).vhd"
# Name of new disk copied in the destination region.
$destinationOSDiskName = "$($snapshotName)-disk"

# Provide the storage type for snapshot. PremiumLRS or StandardLRS.
$storageType = 'Standard_LRS'

# Get source VM properties
$vm = Get-AzVM -Name $vmName `
   -ResourceGroupName $resourceGroupName

# Get source VM OS Disk
$disk = Get-AzDisk -ResourceGroupName $resourceGroupName `
   -DiskName $vm.StorageProfile.OsDisk.Name

# Creates a configurable snapshot object of source VM's OS disk.
$snapshotConfig =  New-AzSnapshotConfig `
   -SourceUri $disk.Id `
   -OsType Windows `
   -CreateOption Copy `
   -Location $disk.Location

# Create Snapshot of the source VM's OS disk
$snapShot = New-AzSnapshot `
   -Snapshot $snapshotConfig `
   -SnapshotName $snapshotName `
   -ResourceGroupName $resourceGroupName

Write-Output "snapshot $snapshotName created"

# Generate the SAS for the snapshot 
$sas = Grant-AzSnapshotAccess -ResourceGroupName $ResourceGroupName -SnapshotName $SnapshotName  -DurationInSecond $sasExpiryDuration -Access Read

# Create the context for the storage account which will be used to copy snapshot to the destination region
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

# Copy the snapshot as a VHD file to the storage account in the destination region
Start-AzStorageBlobCopy -AbsoluteUri $sas.AccessSAS -DestContainer $storageContainerName -DestContext $destinationContext -DestBlob $destinationVHDFileName

# Wait for snapshot VHD file copy completion before we move on
Get-AzStorageBlobCopyState -Blob $destinationVHDFileName -Container $storageContainerName -Context $destinationContext -WaitForComplete
Write-Output "snapshot vhd file $destinationVHDFileName copied to storage account: $storageAccountName and container: $storageContainerName"

# Create the managed disk from the copied snapshot vhd file
# Construct the full URI to the snapshot VHD file blob
$osDiskVhdUri = ($destinationContext.BlobEndPoint + $storageContainerName + "/" + $destinationVHDFileName)
Write-Output "snapshot vhd file blob URI: $osDiskVhdUri"

# Construct the resource Id of the storage account where VHD file is stored. 
$storageAccountId = "/subscriptions/$($Conn.SubscriptionId)/resourceGroups/$($storageResourceGroup)/providers/Microsoft.Storage/storageAccounts/$($storageAccountName)"
Write-Output "Storage account ID: $storageAccountId"

# Create new snapshot in the destination region based on the copied VHD file in the storage account
$snapshotConfig2 = New-AzSnapshotConfig -AccountType $storageType -Location $storageLocation -CreateOption Import -StorageAccountId $storageAccountId -SourceUri $osDiskVhdUri 
$snapshot2 = New-AzSnapshot -Snapshot $snapshotConfig2 -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName-copied
Write-Output "Snapshot: $snapshotName-copied, created in destination region $storageLocation"

# Create new disk from copied snapshot in destination resource grou
$diskConfig = New-AzDiskConfig -SkuName $storageType -Location $storageLocation -CreateOption Copy -SourceResourceId $snapshot2.Id -DiskSizeGB $disk.DiskSizeGB
New-AzDisk -Disk $diskConfig -ResourceGroupName $destinationResourceGroup -DiskName $destinationOSDiskName

Write-Output "Disk: $destinationOSDiskName is created in destination region: $storageLocation"
