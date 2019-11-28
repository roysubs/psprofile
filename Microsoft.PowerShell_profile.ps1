# $Profile additions
# Single line added to $Profile, check if $Profile_additions.ps1 exists, if not download it.

# Can do some work on these settings ...
# https://devblogs.microsoft.com/scripting/customize-the-powershell-console-for-increased-efficiency/

# Is Session Elevated?
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if (Test-Administrator) {$Elevated = "Elevated "}
$TitleDate = Get-Date -format "yyyy-MM-dd HH:mm:ss"
$Host.UI.RawUI.WindowTitle = $Elevated + "PowerShell, started @ " +  $TitleDate

# Remove-Item function:\<function-name>
# That thing that shows all custom functions in this session only!
# For $profile. Running myfunctions will display functions created since the start of the session (i.e.all user-defined functions)
$sysfunctions = gci function:  ;  function myfunctions {gci function: | where {$sysfunctions -notcontains $_} }
From <https://stackoverflow.com/questions/15694338/how-to-get-a-list-of-custom-powershell-functions> 

####################
# Isolate as much as possible away from $profile. All functions should be in Modules whenever possible
####################

# Module: Common-Tools
# Collection of helper functions to constantly update

function syntax($cmd) { Get-Command $cmd -Syntax }   # or (Get-Command $cmd).Definition
function parameter($cmd, $parameter) { Get-Help $cmd -Parameter $parameter }
function examples($cmd) { Get-Help $cmd -Examples }   # or (Get-Command $cmd).Definition

# or these could be for the common-module

# git init
# git add Microsoft.PowerShell_profile.ps1
# git status
# git commit -m "adding files"
# git remote add origin https://github.com/roysubs/psprofile.git
# git pull origin master --allow-unrelated-histories
    # Had to do this to force the merge to happen.
# git push -u origin master
# git clone https://github.com/roysubs/psprofile.git



# https://binarynature.blogspot.com/2010/04/powershell-version-of-df-command.html
# PowerShell equivalent of the df command
# Get-DiskFree | Get-Member
# 'db01','sp01' | Get-DiskFree -Credential $cred -Format | ft -GroupBy Name -auto  
# Name Vol Size  Used  Avail Use% FS   Type
# ---- --- ----  ----  ----- ---- --   ----
# DB01 C:  39.9G 15.6G 24.3G   39 NTFS Local Fixed Disk
# DB01 D:  4.1G  4.1G  0B     100 CDFS CD-ROM Disc
### Low Disk Space: just get list of servers in AD with disk space below 20% for C: volume?
# Import-Module ActiveDirectory
# $servers = Get-ADComputer -Filter { OperatingSystem -like '*win*server*' } | Select-Object -ExpandProperty Name
# Get-DiskFree -cn $servers | Where-Object { ($_.Volume -eq 'C:') -and ($_.Available / $_.Size) -lt .20 } | Select-Object Computer
### Out-GridView: filter on drives of four servers and have the output displayed in an interactive table.
# $cred = Get-Credential 'example\administrator'
# $servers = 'dc01','db01','exch01','sp01'
# Get-DiskFree -Credential $cred -cn $servers -Format | ? { $_.Type -like '*fixed*' } | select * -ExcludeProperty Type | Out-GridView -Title 'Windows Servers Storage Statistics'
### Output to CSV: similar to the previous except we will also sort the disks by the percentage of usage. We've also decided to narrow the set of properties to name, volume, total size, and the percentage of the drive space currently being used.
# $cred = Get-Credential 'example\administrator'
# $servers = 'dc01','db01','exch01','sp01'
# Get-DiskFree -Credential $cred -cn $servers -Format | ? { $_.Type -like '*fixed*' } | sort 'Use%' -Descending | select -Property Name,Vol,Size,'Use%' | Export-Csv -Path $HOME\Documents\windows_servers_storage_stats.csv -NoTypeInformation

# https://www.computerperformance.co.uk/powershell/format-table/
function Get-DiskFree
{
    [CmdletBinding()]param
    (
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('hostname')]
        [Alias('cn')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter(Position=1,
                   Mandatory=$false)]
        [Alias('runas')]
        [System.Management.Automation.Credential()]$Credential =
        [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Position=2)]
        [switch]$Format
    )
    
    BEGIN
    {
        function Format-HumanReadable 
        {
            param ($size)
            switch ($size) 
            {
                {$_ -ge 1PB}{"{0:#.#'P'}" -f ($size / 1PB); break}
                {$_ -ge 1TB}{"{0:#.#'T'}" -f ($size / 1TB); break}
                {$_ -ge 1GB}{"{0:#.#'G'}" -f ($size / 1GB); break}
                {$_ -ge 1MB}{"{0:#.#'M'}" -f ($size / 1MB); break}
                {$_ -ge 1KB}{"{0:#'K'}" -f ($size / 1KB); break}
                default {"{0}" -f ($size) + "B"}
            }
        }
        
        $wmiq = 'SELECT * FROM Win32_LogicalDisk WHERE Size != Null AND DriveType >= 2'
    }
    
    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                if ($computer -eq $env:COMPUTERNAME)
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -ErrorAction Stop
                }
                else
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -Credential $Credential `
                             -ErrorAction Stop
                }
                
                if ($Format)
                {
                    # Create array for $disk objects and then populate
                    $diskarray = @()
                    $disks | ForEach-Object { $diskarray += $_ }
                    
                    $diskarray | Select-Object @{n='Name';e={$_.SystemName}}, 
                        @{n='Vol';e={$_.DeviceID}},
                        @{n='Size';e={Format-HumanReadable $_.Size}},
                        @{n='Used';e={Format-HumanReadable `
                        (($_.Size)-($_.FreeSpace))}},
                        @{n='Avail';e={Format-HumanReadable $_.FreeSpace}},
                        @{n='Use%';e={[int](((($_.Size)-($_.FreeSpace))`
                        /($_.Size) * 100))}},
                        @{n='FS';e={$_.FileSystem}},
                        @{n='Type';e={$_.Description}}
                }
                else 
                {
                    foreach ($disk in $disks)
                    {
                        $diskprops = @{'Volume'=$disk.DeviceID;
                                   'Size'=$disk.Size;
                                   'Used'=($disk.Size - $disk.FreeSpace);
                                   'Available'=$disk.FreeSpace;
                                   'FileSystem'=$disk.FileSystem;
                                   'Type'=$disk.Description
                                   'Computer'=$disk.SystemName;}
                    
                        # Create custom PS object and apply type
                        $diskobj = New-Object -TypeName PSObject `
                                   -Property $diskprops
                        $diskobj.PSObject.TypeNames.Insert(0,'BinaryNature.DiskFree')
                    
                        Write-Output $diskobj
                    }
                }
            }
            catch 
            {
                # Check for common DCOM errors and display "friendly" output
                switch ($_)
                {
                    { $_.Exception.ErrorCode -eq 0x800706ba } `
                        { $err = 'Unavailable (Host Offline or Firewall)'; 
                            break; }
                    { $_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } `
                        { $err = 'Access denied (Check User Permissions)'; 
                            break; }
                    default { $err = $_.Exception.Message }
                }
                Write-Warning "$computer - $err"
            } 
        }
    }  
    END {}
}

# simple df version
# function df {
#     $colItems = Get-wmiObject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername localhost
#     echo "DevID`t FSname`t Size GB`t FreeSpace GB`t Description"
# 
#     foreach ($objItem in $colItems) {
#       $DevID = $objItem.DeviceID
# 		$FSname = $objItem.FileSystem
#       $size = ($objItem.Size / 1GB).ToString("f2")
# 		$FreeSpace = ($objItem.FreeSpace / 1GB).ToString("f2")
# 		$description = $objItem.Description
#       echo "$DevID`t $FSname`t $Size GB`t $FreeSpace GB`t $Description"
#     }	
# }

