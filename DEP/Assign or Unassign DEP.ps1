<#
.SYNOPSIS
Assigns or unassigns ADE (DEP) enrollment profiles to Apple devices.

.DESCRIPTION
This script lets administrators assign or unassign Apple Automated Device Enrollment (ADE) profiles 
to one or more devices by serial number via the Workspace ONE API. Authentication is handled through 
a shared OAuth token cache.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "C:\Path\To\Shared\Token\ws1_token_cache.json"
$tenantCode     = "YOUR_TENANT_CODE"
$orgGroupUuid   = "YOUR_ORG_GROUP_UUID"
$ws1EnvUrl      = "https://yourenv.awmdm.com/api"
$tmpProfileMap  = "$HOME\Downloads\ws1_dep_profile_map.csv"
$profileCsv     = "$HOME\Downloads\DEP_Profiles.csv"

# -------------------------------
# Get OAuth Token from Cache
# -------------------------------
function Get-WS1Token {
    if (-Not (Test-Path $TokenCacheFile)) {
        Write-Host "❌ Token cache not found at $TokenCacheFile" -ForegroundColor Red
        exit 1
    }

    try {
        $tokenData = Get-Content $TokenCacheFile | ConvertFrom-Json
        return $tokenData.access_token
    } catch {
        Write-Host "❌ Failed to parse token cache." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# -------------------------------
# Fetch available DEP profiles
# -------------------------------
function Get-DEPProfiles {
    Write-Host "`n📄 Fetching available DEP profiles..."
    $response = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/enrollment/profiles/search?organizationgroupid=$orgGroupUuid" -Method GET -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json;version=1"
        "aw-tenant-code"= $tenantCode
    }

    if (-not $response.ProfileList) {
        Write-Host "❌ No profiles found."
        exit 1
    }

    $response.ProfileList | Select-Object ProfileId, ProfileName |
        Export-Csv -NoTypeInformation -Path $profileCsv

    Write-Host "✅ Profiles exported to $profileCsv"
}

# -------------------------------
# Assign or Unassign profile
# -------------------------------
function Set-DEPProfile {
    param (
        [string]$serial,
        [string]$profileId
    )

    $uri = if ($profileId -eq "unassign") {
        "$ws1EnvUrl/mdm/devices/aedprofile/unassign"
    } else {
        "$ws1EnvUrl/mdm/devices/aedprofile/assign"
    }

    $body = @{
        serialnumber = $serial
        ProfileId    = if ($profileId -ne "unassign") { $profileId } else { $null }
    } | ConvertTo-Json -Depth 10

    $result = Invoke-RestMethod -Uri $uri -Method POST -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $tenantCode
    } -Body $body -ContentType "application/json"

    if ($result.message) {
        Write-Host "📢 $($result.message)"
    } else {
        Write-Host "✅ Operation successful for $serial"
    }
}

# -------------------------------
# MAIN
# -------------------------------

$AccessToken = Get-WS1Token

Write-Host "`n📘 Assign or Unassign DEP Profile" -ForegroundColor Cyan
Write-Host "1. Assign DEP Profile"
Write-Host "2. Unassign DEP Profile"
Write-Host "3. List Available Profiles"
$option = Read-Host "Enter option [1-3]"

switch ($option) {
    "3" {
        Get-DEPProfiles
        exit 0
    }
    "1" {
        if (-not (Test-Path $profileCsv)) {
            Write-Host "⚠️ Profile CSV not found. Run option 3 first." -ForegroundColor Yellow
            exit 1
        }

        $profiles = Import-Csv $profileCsv
        foreach ($p in $profiles) {
            Write-Host "$($p.ProfileId) — $($p.ProfileName)"
        }

        $profileId = Read-Host "Enter ProfileId to assign"
        if ([string]::IsNullOrWhiteSpace($profileId)) {
            Write-Host "❌ No profile selected. Exiting."
            exit 1
        }
    }
    "2" {
        $profileId = "unassign"
    }
    default {
        Write-Host "❌ Invalid selection." -ForegroundColor Red
        exit 1
    }
}

$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
if ([string]::IsNullOrWhiteSpace($serialInput)) {
    Write-Host "❌ No serial numbers provided."
    exit 1
}
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($serial in $serials) {
    Set-DEPProfile -serial $serial -profileId $profileId
}
