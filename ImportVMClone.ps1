function Import-VMClone {

    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $templateDirectory,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $newVMName,
        [Parameter(Position = 2, Mandatory = $true)]
        [string]
        $newVMDirectory
    )
    
    begin {
    
        try {
    
            if (!(Test-Path $newVMDirectory)) {
    
                New-Item -Path $newVMDirectory -ItemType Directory -ErrorAction Stop
    
            }
    
            else {
    
                Write-Host "New VM Directory already exisits, exiting. Check VM directory to prevent data loss and remove directory if appropriate to import cloned VM." 
                Exit 1
    
            }
    
            #Get Template ID
            $templateVMCXID = (Get-ChildItem $templateDirectory *.vmcx -Recurse).Name
            $templateVMCXID = $templateVMCXID.Split(".")[0]
    
            #Get Template ID Full Path for future Import
            $templateVMCXPath = (Get-ChildItem $templateDirectory *.vmcx -Recurse).FullName
    
        }
    
        catch {
    
            Write-Host $($_.Exception.Message)
    
        }
    
    }
    
    process {
    
        try {
    
            try {

                #Import VM
                Write-Host "Importing VM $newVMName to Hyper-V"
    
                #Specify Import Properties
                $importProps = @{
    
                    Path               = $templateVMCXPath
                    VirtualMachinePath = $newVMDirectory
                    SnapshotFilePath   = $newVMDirectory
                    VhdDestinationPath = $newVMDirectory
                    Copy               = $true
                    GenerateNewID      = $true
    
                }
    
                $importedVM = Import-VM @importProps -ErrorAction Stop
    
    
            }
            
            catch {
    
                Write-Host "Unable to import VM clone due to error: $($_.Exception.Message)"
                Exit 1

            }
    
            try {

                #Change imported VM name
                Write-Host "Changing imported VM name to $newVMName"

                #Head scratcher...shouldn't need this but previous VAR is getting wiped during the rename.
                $importedVMName = $importedVM.Name
                
                #Do the rename
                Get-VM -Name $importedVM.Name | Where-Object { $_.VMId -ne $templateVMCXID } | Rename-VM -NewName $newVMName

                #Get the disks to update the config and have the disks match the VM name
                Write-Host "Getting disks of imported VM"

                $newVMDisks = Get-VMHardDiskDrive -VMName $importedVM.Name -ControllerType SCSI

                foreach ($disk in $newVMDisks) {

                    $diskPath = $disk.Path
                    $newDiskNamePath = ($diskPath.Replace($importedVMName, $newVMName))

                    Write-Host "Removing $disk.Path from Configuration"
                    Remove-VMHardDiskDrive -VMName $newVMName -ControllerType SCSI -ControllerNumber $disk.ControllerNumber -ControllerLocation $disk.ControllerLocation

                    Write-Host "Renaming disks for imported VM to $newVMName"
                    Rename-Item -Path $diskPath -NewName $newDiskNamePath

                    Write-Host "Adding $disk back to $newVMName"
                    Add-VMHardDiskDrive -VMName $disk.VMName -ControllerType SCSI -ControllerNumber $disk.ControllerNumber -ControllerLocation $disk.ControllerLocation -Path $newDiskNamePath

                }

            }

            catch {

                Write-Host "Unable to rename VM. Check VM Name, and files for consistency. Error: $($_.Exception.Message)"

            }

        }

        catch {
    
            Write-Host $($_.Exception.Message)
    
        }

    }
    
    end {
    

    
    }
    
}