## what is this?
A deployment runbook to copy VM OSdisk from one region to another.

The runook expects the following parameters:

	"resourceGroupName": resource group name of the source VM.
	"vmName": VM name which you want to copy it’s OS disk.
	"storageAccountName": storage account name in the destination region used to copy snapshots.
	"storageContainerName": storage container name in the storage account where snapshots will be copied
	"storageLocation": storage account region: example (centralus, westus..) the location should be same of where you want to copy the disk.
	"storageResourceGroup": storage account resource group.
	"destinationResourceGroup": destination resource group where you want to copy the disk.

