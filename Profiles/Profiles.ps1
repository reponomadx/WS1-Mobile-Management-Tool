# -----------------------------------------------------------------------------
# Script Name: Get-DeviceProfiles.ps1
# Purpose: Retrieve installed configuration profiles for Workspace ONE devices
# Description:
#   This script queries installed device profiles via the Workspace ONE API
#   using either serial numbers or user IDs. Profile name, version, and
#   assignment type are retrieved for each device and saved to a CSV file.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
# Token and output directory paths
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600
$Ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$OutputDir = "\\HOST_SERVER\MobileManagementTool\Profiles"
$CsvFile = "$HOME\Downloads\device_profiles.csv"

# Ensure directories exist
if (-not (Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory | Out-Null }
if (-not (Test-Path (Split-Path $TokenCacheFile))) { New-Item -Path (Split-Path $TokenCacheFile) -ItemType Directory | Out-Null }
if (-not (Test-Path (Split-Path $CsvFile))) { New-Item -Path (Split-Path $CsvFile) -ItemType Directory | Out-Null }

# Initialize CSV output
"" | Set-Content $CsvFile
"Device Name,Serial Number,Profile Name,Installed Version,Assignment Type" | Add-Content $CsvFile

# -------------------------------
# FUNCTION: Get-WS1Token
# Retrieves and uses a cached OAuth access token
# -------------------------------
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $tokenAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($tokenAge.TotalSeconds -lt $TokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "❌ Access token is missing or expired. Please wait for the hourly renewal task or contact IT support."
    exit 1
}

# -------------------------------
# FUNCTION: Get-Profiles
# Retrieves installed profiles for a specific device
# -------------------------------
function Get-Profiles {
    param (
        [string]$deviceId,
        [string]$serial,
        [string]$deviceName
    )

    Write-Host "`n📋 Querying installed profiles for Device: $deviceName ($serial)"
    Write-Host "-----------------------------"

    try {
        $url = "$Ws1EnvUrl/mdm/devices/$deviceId/profiles"
        $response = Invoke-RestMethod -Uri $url -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Accept"        = "application/json;version=1"
        }

        $profiles = $response.DeviceProfiles
        if (-not $profiles -or $profiles.Count -eq 0) {
            Write-Host "⚠️  No profiles found for device ID $deviceId."
            return
        }

        foreach ($profile in $profiles) {
            Write-Host "• $($profile.Name)"
            Write-Host "   - Installed Version: $($profile.InstalledProfileVersion)"
            Write-Host "   - Assignment Type: $($profile.AssignmentType)"

            "$deviceName,$serial,$($profile.Name),$($profile.InstalledProfileVersion),$($profile.AssignmentType)" | Add-Content -Path $CsvFile
        }
    } catch {
        Write-Host "❌ Failed to retrieve profile data for device ID $deviceId"
        Write-Host $_.Exception.Message
    }
}

# -------------------------------
# MAIN
# -------------------------------
Write-Host "`nProfiles"
Write-Host "Choose search type:"
Write-Host "1. Serial Number"
Write-Host "2. User ID"
$searchOption = Read-Host "Enter option [1-2]"

$apiMode = ""
$identifiers = @()

# Input validation
if ($searchOption -eq "1") {
    $apiMode = "serial"
    $input = Read-Host "`nEnter one or more 10 or 12-character serial numbers (comma-separated)"
    $input -split "," | ForEach-Object {
        $id = $_.Trim()
        if ($id -notmatch '^[A-Za-z0-9]{10,12}$') {
            Write-Host "❌ Invalid serial number: $id"
        } else {
            $identifiers += $id
        }
    }
}
elseif ($searchOption -eq "2") {
    $apiMode = "user"
    $input = Read-Host "`nEnter one or more User IDs (comma-separated)"
    $identifiers = $input -split "," | ForEach-Object { $_.Trim() }
}
else {
    Write-Host "❌ Invalid option selected."
    exit 1
}

# Get access token
$accessToken = Get-WS1Token

# Search by serial number
if ($apiMode -eq "serial") {
    foreach ($serial in $identifiers) {
        try {
            $deviceLookup = Invoke-RestMethod "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
                "Authorization" = "Bearer $accessToken"
                "Accept"        = "application/json"
            }

            $deviceId = $deviceLookup.Id.Value
            $deviceName = $deviceLookup.DeviceFriendlyName

            if (-not $deviceId) {
                Write-Host "❌ Could not resolve Device ID for serial number $serial. Skipping."
                continue
            }

            Get-Profiles -deviceId $deviceId -serial $serial -deviceName $deviceName
        } catch {
            Write-Host "❌ Failed to query serial $serial"
            Write-Host $_.Exception.Message
        }
    }
}
# Search by user ID
else {
    foreach ($user in $identifiers) {
        try {
            $deviceLookup = Invoke-RestMethod "$Ws1EnvUrl/mdm/devices/search?user=$user" -Headers @{
                "Authorization" = "Bearer $accessToken"
                "Accept"        = "application/json"
            }

            if (-not $deviceLookup.Devices) {
                Write-Host "❌ No devices found for user ID: $user"
                continue
            }

            foreach ($device in $deviceLookup.Devices) {
                $deviceId = $device.Id.Value
                $deviceName = $device.DeviceFriendlyName
                $serial = $device.SerialNumber

                Get-Profiles -deviceId $deviceId -serial $serial -deviceName $deviceName
            }
        } catch {
            Write-Host "❌ Failed to query user ID: $user"
            Write-Host $_.Exception.Message
        }
    }
}

Write-Host "`n✅ Profile data saved to $CsvFile"
