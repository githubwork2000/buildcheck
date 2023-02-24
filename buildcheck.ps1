function Check-RAMMatch($RAM,$RAMVariable){
      if ($RAM -eq $RAMVariable){
          return $true
      } else {
          return $false
      }
}

function Check-CPUMatch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [int]$TargetCPU
    )

    $ActualCPU = (Get-CimInstance Win32_Processor).numberoflogicalprocessors

    if ($ActualCPU -eq $TargetCPU) {
        "The Actual CPU matches the Target CPU"
    } else {
        "The Actual CPU does not match the Target CPU"
    }
}

function Check-DiskSize {
    param(
        [String]$diskName,
        [Int]$desiredSize
    )

    # Get the drive object using the disk name
    $disk = Get-Volume -Name $diskName

    # Check if the size of the disk is smaller than desired
    if ($disk.Size -lt $desiredSize) {
        # If it is, return false
        Write-Host "Disk size is less than desired size" -ForegroundColor Red
        $returnValue = $false
    } else {
        # Else if it is larger than or equal to the desired size, return true
        Write-Host "Disk size is larger than or equal to desired size" -ForegroundColor Green
        $returnValue = $true
    } 

    # Return the value
    return $returnValue
}

function Test-NetworkConnection($hostname){
    $networkConnectionTest = Test-NetConnection -ComputerName $hostname -CommonTCPPort 443
    if ($networkConnectionTest.TcpTestSucceeded -eq $true){
        write-host "Connection to $hostname successful"
    } else{
        write-host "Connection to $hostname failed"
    }
}

function Check-DNS {
  param($dnsVariable)
  
  # Get all the networking adapters
  $networkAdapters = Get-NetipConfiguration | Select-Object -ExpandProperty InterfaceAlias
  
  # Check each adapter's DNS server
  foreach($adapter in $networkAdapters) {
    $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $adapter).ServerAddresses
    if($dnsServers -notcontains $dnsVariable) {
      return $false
    }
  }
  
  return $true
}

function Check-TimeZone {
    [CmdletBoundaryAttribute()]
    Param ( 
        [Parameter(Mandatory = $true)]
        [System.String]$TimeZone, 

        [Parameter(Mandatory = $true)] 
        [System.Management.Automation.PSObject]$Computer 
    )

    # Get the current system time zone.
    $CurrentTimeZone = (Get-WmiObject -Class "Win32_TimeZone" -ComputerName $Computer).StandardName

    # Compare the time zones.
    if ($TimeZone -eq $CurrentTimeZone) {
        return $true
    } 
    else {
        return $false
    }
}

function Check-GroupPolicyAgainstVariable {
  param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Variable
  )

  # Initialize the empty array of group policy names
  $policyNames = @()

  # Get the group policies configured on the computer
  # This cmdlet will get both Machine and User configurations 
  $collection = Get-GPO -All

  # Iterate over all the found group policies
  foreach($gpObject in $collection) {

    # Get the domain path of the current policy 
    $domainPath = $gpObject.Domain.split(".")

    # Add the name of the policy to the array 
    $policyNames += ($domainPath[$domainPath.Length - 1] + '\') + 
                    $gpObject.DisplayName
  }

  # Compare the array of policy names against the input variable
  if($Variable -notin $policyNames) { 
      Write-Output "The policy $Variable is not present on this machine."
  } else {
      Write-Output "The policy $Variable is applied to this machine."
  }  
}

## Usage example
#$variable = 'Default Domain Policy'
#Check-GroupPolicyAgainstVariable -Variable $variable


Function Check-DSCStatus {
    Param (
        [string]$ComputerName
    )

    # Get all available DSC configurations
    $AllConfigurations = Get-DscConfiguration -ComputerName $ComputerName 

    # Get the decided configuration
    $CurrentDSCConfig = Get-DscLocalConfigurationManager -ComputerName $ComputerName

    # Iterate through each configuration
    foreach ($Config in $AllConfigurations){
        if($CurrentDSCConfig.ConfigurationMode -eq $Config.ConfigurationMode){
            $Name = $Config.Name.Substring($Config.Name.LastIndexOf("\") + 1)
            Write-Host "Checking $Name configuration..." -ForegroundColor Cyan

            # Compare current DSC status with the decided configuration
            $CompareResult = Compare-DscConfiguration -ComputerName $ComputerName -Path C:\Program Files\WindowsPowerShell\DscService\Configuration -ConfigurationMode $Config.ConfigurationMode
            if($CompareResult.Status -eq "Success"){
                Write-Host "The $Name configuration is up to date." -ForegroundColor Green
            } else {
                Write-Host "The $Name configuration is not up to date." -ForegroundColor Red
            }
        }
    }
}

Function Get-DownloadFile
{
    #download diskspd.exe from internet
    $url = 'https://github.com/Microsoft/diskspd/releases/latest/download/DiskSpd.zip'
    Invoke-WebRequest -Uri $url -OutFile ('diskspd.zip') -UseBasicParsing
    Expand-Archive DiskSpd.zip
}

function Test-DriveSpeed {

    #need to CD to each mountpoint, otherwise diskspd doesnt like the drive supplied
    #C:\Users\Administrator\DiskSpd\amd64\diskspd -c2G -b4K -F8 -r -o32 -W60 -d60 -Sh testfile.dat
  $result = & .\diskspd\amd64\diskspd.exe 
  return $result
}


Function Get-LocalMountPoints {
    $mounts = Get-WmiObject Win32_Volume -Filter 'DriveType=3'
    $mounts | Select-Object @{Name="Label";Expression={$_.Label}},@{Name="Name";Expression={$_.Name}},@{Name="Available";Expression={[math]::Round($_.FreeSpace/1GB,2) + ' GB'}} 
}

Get-LocalMountPoints


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
}

Main