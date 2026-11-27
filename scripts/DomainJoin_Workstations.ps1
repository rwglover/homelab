<#
.SYNOPSIS  Renames PC and joins it to the domain in one step.
.EXAMPLE   .\Join-Domain.ps1            # dry run: pre-flight checks only
.EXAMPLE   .\Join-Domain.ps1 -Commit    # renames, joins and reboots
#>
param(
    [string]$DomainName = 'ad.rwglover.com',
    # [string]$NewName    = '******',
    [string]$NewName    = 'WIN11-CLIENT', 
    [string]$OUPath     = 'OU=Workstations,OU=Computers,OU=RWG,DC=ad,DC=rwglover,DC=com',
    [string]$DCAddress  = '172.20.20.10',
    [switch]$Commit
)

$Log = "C:\Temp\Join-Domain_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
function Write-Step($Msg, $Status) {
    $color = @{ OK='Green'; WARN='Yellow'; FAIL='Red'; INFO='Cyan' }[$Status]
    Write-Host "[$Status] $Msg" -ForegroundColor $color
    [pscustomobject]@{ Time=(Get-Date); Status=$Status; Step=$Msg } |
        Export-Csv $Log -Append -NoTypeInformation
}

# Pre-flight checks. Every check runs, so you see all problems at once.
$fail = 0
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')
if ($isAdmin) { Write-Step 'Running as administrator' OK } else { Write-Step 'Not running as administrator' FAIL; $fail++ }

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) { Write-Step 'Already joined to a domain' FAIL; $fail++ }
else { Write-Step 'Not yet domain-joined' OK }

$dns = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses
if ($dns -contains $DCAddress) { Write-Step "DNS points to DC ($DCAddress)" OK }
else { Write-Step "DNS is $($dns -join ', '), expected $DCAddress" FAIL; $fail++ }

try {
    Resolve-DnsName "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop | Out-Null
    Write-Step "Domain controller SRV record found for $DomainName" OK
} catch { Write-Step "Cannot locate a DC for $DomainName via DNS" FAIL; $fail++ }

if (Test-NetConnection $DCAddress -Port 389 -InformationLevel Quiet -WarningAction SilentlyContinue) {
    Write-Step "LDAP (389) reachable on $DCAddress" OK
} else { Write-Step "LDAP (389) blocked to $DCAddress, check firewall rules" FAIL; $fail++ }

if ($fail) { Write-Step "$fail check(s) failed. Fix them before joining." FAIL; exit 1 }

$renaming = $env:COMPUTERNAME -ne $NewName
if (-not $Commit) {
    $plan = if ($renaming) { "rename $env:COMPUTERNAME to $NewName and " } else { '' }
    Write-Step "DRY RUN: would ${plan}join $DomainName into $OUPath" WARN
    Write-Step 'Rerun with -Commit to apply.' INFO
    exit 0
}

# Apply
$cred = Get-Credential -Message "Account with rights to join computers to $DomainName"
$join = @{ DomainName=$DomainName; OUPath=$OUPath; Credential=$cred; Restart=$true; Force=$true }
if ($renaming) { $join.NewName = $NewName }
Write-Step "Joining $DomainName. The PC will reboot." INFO
Add-Computer @join
