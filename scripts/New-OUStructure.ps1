<#
.SYNOPSIS  Builds the RWG OU structure in the current domain. Safe to rerun.
.EXAMPLE   .\New-OUStructure.ps1            # dry run: shows what would be created
.EXAMPLE   .\New-OUStructure.ps1 -Commit    # creates the missing OUs
#>
param([switch]$Commit)

Import-Module ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName
$Log = "C:\Temp\New-OUStructure_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null

function Write-Step($Msg, $Status) {
    $color = @{ OK='Green'; WARN='Yellow'; FAIL='Red'; INFO='Cyan'; SKIP='DarkGray' }[$Status]
    Write-Host "[$Status] $Msg" -ForegroundColor $color
    [pscustomobject]@{ Time=(Get-Date); Status=$Status; Step=$Msg } |
        Export-Csv $Log -Append -NoTypeInformation
}

# OU paths, parent first. Duplicates removed; sorted by depth so parents are created first.
$OUs = @(
    'RWG'
    'RWG/Admin', 'RWG/Admin/Tier0', 'RWG/Admin/Tier1', 'RWG/Admin/Tier2'
    'RWG/Users', 'RWG/Users/Staff', 'RWG/Users/Disabled'
    'RWG/Groups'
    'RWG/Computers', 'RWG/Computers/Servers', 'RWG/Computers/Workstations'
    'RWG/Service Accounts'
) | Select-Object -Unique | Sort-Object { ($_ -split '/').Count }

$created = 0; $skipped = 0
foreach ($path in $OUs) {
    $parts  = $path -split '/'
    $name   = $parts[-1]
    $parent = if ($parts.Count -gt 1) { @($parts[0..($parts.Count - 2)]) } else { @() }
    #[array]::Reverse($parent) //Resulted in Error when dry running script
    if ($parent) { [array]::Reverse($parent) }
    $parentDN = (@($parent | ForEach-Object { "OU=$_" }) + $DomainDN) -join ','
    $dn = "OU=$name,$parentDN"

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Step "Exists: $dn" SKIP; $skipped++
    }
    elseif (-not $Commit) {
        Write-Step "Would create: $dn" WARN; $created++
    }
    else {
        New-ADOrganizationalUnit -Name $name -Path $parentDN -ProtectedFromAccidentalDeletion $true
        Write-Step "Created: $dn" OK; $created++
    }
}

$verb = if ($Commit) { 'Created' } else { 'Would create' }
Write-Step "$verb $created OU(s), skipped $skipped existing. Log: $Log" INFO
if (-not $Commit) { Write-Step 'Dry run only. Rerun with -Commit to apply.' INFO }
