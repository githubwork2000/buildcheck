function Compare-RAM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$RAM
    )

    $bytes = (Get-WmiObject -class "cim_physicalmemory" | Measure-Object -Property Capacity -Sum).Sum
    $gig = ($bytes / 1024 / 1024 / 1024)

    if ($RAM -like $gig) {
        return $true
    }
    else {
        return $false
    }
}

function Compare-CPU {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$TargetCPU
    )

    $ActualCPU = (Get-CimInstance Win32_Processor).numberoflogicalprocessors

    if ($ActualCPU -eq $TargetCPU) {
        return $true
    }
    else {
        return $false
    }
}

Function Test-IfValuesPresent {
    <#
    .SYNOPSIS
    This function will compare the items of two arrays and check if all the items from one
    array exists in the other array.
    #>
    
    Param (
        [Parameter(Mandatory)]$ArrayA,
        [Parameter(Mandatory)]$ArrayB
    )
        
    $ElementsInA = @()
    foreach ($element in $ArrayA) {
        if ($ArrayB -contains $element) {
            $ElementsInA += $element
        }
    }
    if ($ArrayA.Length -eq $ElementsInA.Length) {
        Write-Output $True
    }
    else {
        Write-Output $False
    }
}

function Compare-Disksizes {
    Param (
        [Parameter(Mandatory)][Array]$disksizesneeded
    )
    $alldisksizes = @()

    # Get list of disks
    $disks = Get-PhysicalDisk

    # Build the output object
    foreach ($disk in $disks) { 
        # Calculate size in GB
        $size = [Math]::Round(($disk.Size / 1024 / 1024 / 1024), 2)
                                                 
        $alldisksizes += $size
    }

    $ElementsInA = @()
    foreach ($element in $disksizesneeded) {
        if ($alldisksizes -contains $element) {
            $ElementsInA += $element
        }
    }
    if ($disksizesneeded.Length -eq $ElementsInA.Length) {
        Write-Output $True
    }
    else {
        Write-Output $False
    }

}

function Test-NetworkConnection($hostname) {
    $networkConnectionTest = Test-NetConnection -ComputerName $hostname -CommonTCPPort SMB #need to change port probably
    if ($networkConnectionTest.TcpTestSucceeded -eq $true) {
        return $True
    }
    else {
        return $False
    }
}

function Test-PingIP { 
    param ([string]$IPAddr) 
 
    # Use the Test-Connection cmdlet to test a connection towards the specified IP address 
    # Use errors action silentlycontinue in case the IP is unavailable
    $result = Test-Connection -ComputerName $IPAddr -Count 1 -ErrorAction SilentlyContinue 
 
    # if Test-Conection returns no results, return false
    if (-not $result) { 
        return $false; 
    }
    else {
        # Results were returned, so return true
        return $true;
    } 
}

function Compare-DNS {
    #we can make an array here if needed
    param($dnsVariable)
  
    # Get all the networking adapters
    $networkAdapters = Get-NetipConfiguration | Select-Object -ExpandProperty InterfaceAlias
  
    # Check each adapter's DNS server
    foreach ($adapter in $networkAdapters) {
        $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $adapter).ServerAddresses
        if ($dnsServers -notcontains $dnsVariable) {
            return $false
        }
    }
  
    return $true
}

function Compare-TimeZone {
    Param ( 
        [Parameter(Mandatory = $true)]
        [System.String]$TimeZone
    )

    # Get the current system time zone.
    [System.String]$CurrentTimeZone = (Get-WmiObject -Class "Win32_TimeZone").StandardName
    # Compare the time zones.
    if ($CurrentTimeZone -match $TimeZone) {
        return $true
    }
    else {
        return $false
    }
}

function Get-GroupPolicyAgainstVariable {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Variable
    )

    # Initialize the empty array of group policy names
    $policyNames = @()

    # Get the group policies configured on the computer
    # This cmdlet will get both Machine and User configurations 
    $collection = Get-GPO -All #you have to be using a domain account for this to work.

    # Iterate over all the found group policies
    foreach ($gpObject in $collection) {

        # Add the name of the policy to the array 
        $policyNames += $gpObject.DisplayName
    }

    # Compare the array of policy names against the input variable
    if ($Variable -notin $policyNames) { 
        Write-Output "The policy $Variable is not present on this machine."
    }
    else {
        Write-Output "The policy $Variable is applied to this machine."
    }  
}


Function Test-DSCStatus {
    $resultStatus = Get-DscConfigurationStatus | Select-Object Status -ExpandProperty Status
    if ($resultStatus -eq "Success") {
        return $True
    }
    else {
        return $False
    }
        
    
}

Function Get-DownloadFile {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #download diskspd.exe from internet
    $url = 'https://github.com/Microsoft/diskspd/releases/latest/download/DiskSpd.zip'
    Invoke-WebRequest -Uri $url -OutFile ('diskspd.zip') -UseBasicParsing
    Expand-Archive DiskSpd.zip -Force
}

function Test-DriveSpeed {
    $result = & .\diskspd\amd64\diskspd.exe -c2G -b4K -F8 -r -o32 -W60 -d60 -Sh testfile.dat
    return $result
}


Function Get-LocalMountPoints {
    $mounts = Get-WmiObject Win32_Volume -Filter 'DriveType=3'
    $mounts | Select-Object @{Name = "Label"; Expression = { $_.Label } }, @{Name = "Name"; Expression = { $_.Name } }, @{Name = "Available"; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) + ' GB' } } 
}

Fucntion Get-NonWindowsServices {
    $NonDefaultServices = Get-wmiobject win32_service | where { $_.Caption -notmatch "Windows" -and $_.PathName -notmatch "Windows" -and
    $_.PathName -notmatch "policyhost.exe" -and $_.Name -ne "LSM" -and $_.PathName -notmatch "OSE.EXE" -and $_.PathName -notmatch
    "OSPPSVC.EXE" -and $_.PathName -notmatch "Microsoft Security Client" }

$NonDefaultServices.DisplayName
}

function Main {
    Clear-Host
    Write-Output @'
____        _ _     _  _____ _               _    
|  _ \      (_) |   | |/ ____| |             | |   
| |_) |_   _ _| | __| | |    | |__   ___  ___| | __
|  _ <| | | | | |/ _` | |    | '_ \ / _ \/ __| |/ /
| |_) | |_| | | | (_| | |____| | | |  __/ (__|   < 
|____/ \__,_|_|_|\__,_|\_____|_| |_|\___|\___|_|\_\
                                                   

'@

    Write-Output "Comparing CPU"
    Compare-CPU 12
    Write-Output "Comparing RAM"
    Compare-RAM 8
    Write-Output "Comparing Disk Sizes"
    Compare-Disksizes 127, 20
    Write-Output "Testing host"
    Test-NetworkConnection localhost
    Write-Output "Testing IP"
    Test-PingIP 1.1.1.1
    Write-Output "Comparing Time Zone"
    Compare-TimeZone Pacific
    Write-Output "Testing DSC"
    Test-DSCStatus
    Write-Output "Downloading diskspd"
    Get-DownloadFile
    Write-Output "Testing disk speed (this can take awhile)"
    Test-DriveSpeed
    Write-Output "Getting Mount Points"
    Get-LocalMountPoints
    Write-Output "Comparing GPO Name"
    Get-GroupPolicyAgainstVariable 'Default Domain Policy'
    Write-Output "Getting Non-Windows Services"
    Get-NonWindowsServices

}

Main