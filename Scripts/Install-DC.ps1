<#
.SYNOPSIS  Promotes this server to the first DC of a new AD forest.
.EXAMPLE   .\Install-DC.ps1            # dry run: checks only
.EXAMPLE   .\Install-DC.ps1 -Commit    # installs AD DS and promotes
#>

param(
    [string]$DomainName  = 'ad.rwglover.com',
    [string]$NetBIOSName = 'RWGLOVER',
    [string]$Hostname    = 'DC01',
    [switch]$Commit
)

$Log = "C:\Temp\Install-DC_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null

function Write-Step($Msg, $Status) {
    $color = @{ OK='Green'; WARN='Yellow'; FAIL='Red'; INFO='Cyan' }[$Status]
    Write-Host "[$Status] $Msg" -ForegroundColor $color
    [pscustomobject]@{ Time=(Get-Date); Status=$Status; Step=$Msg } |
        Export-Csv $Log -Append -NoTypeInformation
}

# Pre-Change Checks
if ($env:COMPUTERNAME -ne $Hostname) { Write-Step "Hostname is $env:COMPUTERNAME, expected $Hostname" FAIL; exit 1 }
Write-Step "Hostname is $Hostname" OK

$ip = Get-NetIPAddress -AddressFamily IPv4 | ? { $_.PrefixOrigin -eq 'Manual' }
if (-not $ip) { Write-Step 'No static IPv4 address found' FAIL; exit 1 }
Write-Step "Static IP $($ip.IPAddress)" OK

if (-not $Commit) {
    Write-Step "DRY RUN: would install AD DS and create forest $DomainName ($NetBIOSName)" WARN
    Write-Step 'Rerun with -Commit to apply' INFO
    exit 0
}

# Promote & Apple
Write-Step 'Installing AD DS role' INFO
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Null
Write-Step 'AD DS role installed' OK

$dsrm = Read-Host -AsSecureString 'DSRM (recovery) password'
Write-Step "Creating forest $DomainName, server will reboot" INFO
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetBIOSName `
    -InstallDns -SafeModeAdministratorPassword $dsrm -Force
