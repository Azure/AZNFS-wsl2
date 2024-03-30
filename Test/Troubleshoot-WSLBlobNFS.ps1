# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# To-do:
# - Add connection troubleshooting steps.

$linuxDistribution = "Ubuntu-22.04"

function Get-ClientDiagnosticInfo
{
    # Output results to file
    $filePath = $env:TEMP + "\" +"wslblobnfs-diagnostic-details.txt"

    # Module details
    Write-Host "Collecting Module info."
    $wslModuleDetails = Get-Module -ListAvailable -Name WSLBlobNFS | Select-Object -Property * | Out-String

    # Azure VM details
    $azureVmInfo = $(Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Proxy $Null -Uri "http://169.254.169.254/metadata/instance?api-version=2021-01-01" -TimeoutSec 3) 2>&1

    $azureVMCompute = ""
    if ($azureVmInfo -match "compute")
    {
        $azureVMCompute = $azureVmInfo.compute | Out-String
    }

    $azureVMNetwork = ""
    if ($azureVmInfo -match "compute")
    {
        $azureVMNetwork = $azureVmInfo.network | Out-String
    }

    # Collect system info
    Write-Host "Collecting system info."
    $systemInfo = Get-ComputerInfo | Out-String

    # Collect PowerShell details
    Write-Host "Collecting PowerShell details."
    $psVersion = $PSVersionTable | Out-String

    # Collect WSL info
    Write-Host "Collecting WSL info."
    $wslInfo1 = wsl.exe -l -v 
    $wslInfo1 = $wslInfo1 -replace '\0', '' | Out-String
    $wslInfo1Status = $LastExitCode
    $wslInfo2 = wsl.exe -v 
    $wslInfo2 = $wslInfo2 -replace '\0', '' | Out-String
    $wslInfo2Status = $LastExitCode

    Write-Host "Collecting the list of users on wsl."
    $wslUsers = wsl.exe -d $linuxDistribution -- cat /etc/passwd 2>&1 | Out-String

    # Log the details

    "ModuleDetails: $wslModuleDetails`n" | Out-File $filePath
    "AzureVmInfo: $azureVMCompute `n$azureVMNetwork `nSystemInfo: $systemInfo `nPSVersion: $psVersion `nwslDistro: $wslInfo1 `nwslInfo1Status: $wslInfo1Status `nwslVersion: $wslInfo2 `nwslInfo2Status: $wslInfo2Status `nwslUsers: $wslUsers" | Out-File $filePath -Append

    Write-Host "Please share the following diagnostic file with the Azure Support team $filePath."
}

function Test-WindowThroughput
{
    param(
        # SMB Mounted drive
        [Parameter(Mandatory)]
        [string]$mountdrive
    )
    # # Validate the mount drive
    if($mountdrive -eq $null)
    {
        Write-Host "Mount drive is not specified. Please specify the mount drive."
        exit
    }

    $filePath = $env:TEMP + "\" +"wslblobnfs-throughput-details.txt"

    # Check if fio is installed
    $fioInstalled = Get-Command -Name fio -ErrorAction SilentlyContinue
    if ($null -eq $fioInstalled)
    {
        # Install fio
        Write-Host "Downloading fio."
        Invoke-WebRequest -Uri "https://github.com/axboe/fio/releases/download/fio-3.36/fio-3.36-x64.msi" -OutFile fio-3.36-x64.msi

        Write-Host "Installing fio."
        $arguments = "/i `"fio-3.36-x64.msi`""
        Start-Process msiexec.exe -ArgumentList $arguments -Wait
    }
    else
    {
        Write-Host "fio is already installed."
    }

    # Save the current directory
    $dir = $pwd

    # Change the directory to the mount drive
    Set-Location -Path "$mountdrive\"
    $random = Get-Random
    $fiodir = New-Item -Name fio-samba-$random -ItemType Directory
    Set-Location -Path $fiodir

    Write-Host "Using the following directory to run fio: $pwd."
    Write-Host "Collecting throughput details in the following file: $filePath."
    "Path: $pwd" | Out-File $filePath

    # Run fio
    Write-Host "Running fio write."
    Write-Host "Testhook writes..."
    $fiothwrite = fio --randrepeat=0 --name=fio-samba-testhook-write --filename=..TestHook --bs=1M --direct=1 --numjobs=1 --iodepth=256 --size=10G --rw=write --ioengine=windowsaio | Out-String

    "`nfio-samba-testhook-write: $fiothwrite" | Out-File $filepath -Append

    Write-Host "File writes..."
    $fiofwrite = fio --randrepeat=0 --name=fio-samba-file-write --filename=fio.samba.10g.write --bs=1M --direct=1 --numjobs=1 --iodepth=256 --size=10G --rw=write --ioengine=windowsaio | Out-String

    "`nfio-samba-file-write: $fiofwrite" | Out-File $filePath -Append

    Write-Host "Running fio read."
    Write-Host "Testhook reads..."
    $fiothread = fio --randrepeat=0 --name=fio-samba-testhook-read --filename=..TestHook --bs=1M --numjobs=1 --iodepth=256 --size=10G --rw=read --ioengine=windowsaio | Out-String

    "`nfio-samba-testhook-read: $fiothread" | Out-File $filePath -Append

    Write-Host "File reads..."
    $fiofread = fio --randrepeat=0 --name=fio-samba-file-read --filename=fio.samba.10g.read --bs=1M --numjobs=1 --iodepth=256 --size=10G --rw=read --ioengine=windowsaio | Out-String

    "`nfio-samba-file-read: $fiofread" | Out-File $filePath -Append

    # Change the directory back to the original directory
    Set-Location -Path $dir

    Write-Host "Please share the following throughput details file with the Azure Support team $filePath."
}

function Test-WSL2Throughput
{
    # Run the troubeleshooting script for linux
}