# -----------------------------------------------------------------------------
# Script Name: QueryDeviceApps.ps1
# Purpose: Retrieve and export installed application info from Workspace ONE
# Description:
#   Queries devices by serial number or user ID using Workspace ONE APIs and 
#   retrieves app installation data. The results are exported to a CSV file.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

# Directory to store cached OAuth token
$OAuthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600  # Token validity window in seconds

# Workspace ONE environment and OAuth config (replace placeholders before deployment)
$Ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$TokenUrl = "https://na.uemauth.vmwservices.com/connect/token"
$ClientId = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"

# Output file location and initialization
$OutputDir = "\\HOST_SERVER\MobileManagementTool\Apps"
$CsvFile = "$HOME\Downloads\device_apps.csv"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Prepare CSV file with headers
"" | Set-Content $CsvFile
"Device Name,Serial Number,App Name,Assignment Status,Installed Status,Assigned Version,Latest UEM Action" | Add-Content $CsvFile

# --------------------------------
# TOKEN FUNCTION
# --------------------------------

# Fetch or cache Workspace ONE access token using client credentials
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $tokenAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($tokenAge.TotalSeconds -lt $TokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "🔐 Requesting new Workspace ONE access token..."
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $response = Invoke-RestMethod -Uri $TokenUrl -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"

    if (-not $response.access_token) {
        Write-Host "❌ Failed to obtain access token. Exiting."
        exit 1
    }

    # Ensure token directory exists
    $parentDir = Split-Path $TokenCacheFile
    if (-not (Test-Path $parentDir)) {
        New-Item -Path $parentDir -ItemType Directory | Out-Null
    }

    $response | ConvertTo-Json | Set-Content -Path $TokenCacheFile
    return $response.access_token
}

# --------------------------------
# HELPER FUNCTION
# --------------------------------

# Retrieves and logs installed app data for a given device UUID
function Get-AppInfo {
    param (
        [string]$uuid,
        [string]$deviceName,
        [string]$serial
    )

    Write-Host "`n📦 Installed Applications for Device: $deviceName ($serial)"
    Write-Host "------------------------------------------"

    try {
        $appResponse = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices/$uuid/apps/search" -Headers @{
            "Authorization"  = "Bearer $accessToken"
            "Accept"         = "application/json;version=1"
        }

        if (-not $appResponse.app_items) {
            Write-Host "No app data found."
            return
        }

        foreach ($app in $appResponse.app_items) {
            # Display to console
            Write-Host "• $($app.name)"
            Write-Host "   - Assigned: $($app.assignment_status)"
            Write-Host "   - Installed: $($app.installed_status)"
            Write-Host "   - Version: $($app.assigned_version)"
            Write-Host "   - Action: $($app.latest_uem_action)"

            # Append to CSV
            "$deviceName,$serial,$($app.name),$($app.assignment_status),$($app.installed_status),$($app.assigned_version),$($app.latest_uem_action)" |
                Add-Content -Path $CsvFile
        }
    } catch {
        Write-Host "❌ Error retrieving apps for $deviceName ($serial)"
        Write-Host $_.Exception.Message
    }
}

# --------------------------------
# INPUT & MAIN LOGIC
# --------------------------------

Write-Host "`nApps (Query)"
Write-Host "Choose search type:"
Write-Host "1. Serial Number"
Write-Host "2. User ID"
$searchOption = Read-Host "Enter option [1-2]"

$apiMode = ""
$identifiers = @()

# Collect and validate serial numbers or user IDs
if ($searchOption -eq "1") {
    $apiMode = "serial"
    $input = Read-Host "`nEnter one or more 10/12-character serial numbers (comma-separated)"
    $input -split "," | ForEach-Object {
        $id = $_.Trim()
        if ($id -notmatch '^[A-Za-z0-9]{10,12}$') {
            Write-Host "❌ Invalid serial number: $id"
            exit 1
        }
        $identifiers += $id
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

Write-Host "`nYou entered the following identifiers:`n"
$identifiers | ForEach-Object { Write-Host "- $_" }

# Get valid token before device queries
$accessToken = Get-WS1Token
Write-Host "`n📋 Retrieving device details from Workspace ONE..."

# Loop through each serial/user ID and collect app data
foreach ($id in $identifiers) {
    try {
        if ($apiMode -eq "serial") {
            $response = Invoke-RestMethod "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$id" -Headers @{
                "Authorization" = "Bearer $accessToken"
                "Accept"        = "application/json"
            }

            $uuid = $response.Uuid
            $deviceName = $response.DeviceFriendlyName
            $serial = $response.SerialNumber

            if ([string]::IsNullOrEmpty($uuid) -or $uuid -eq "null") {
                Write-Host "⚠️  Device UUID is missing or invalid for serial: $serial"
                continue
            }

            Get-AppInfo -uuid $uuid -deviceName $deviceName -serial $serial
        }
        else {
            $response = Invoke-RestMethod "$Ws1EnvUrl/mdm/devices/search?user=$id" -Headers @{
                "Authorization" = "Bearer $accessToken"
                "Accept"        = "application/json"
            }

            if (-not $response.Devices) {
                Write-Host "❌ No devices found for user: $id"
                continue
            }

            foreach ($device in $response.Devices) {
                $uuid = $device.Uuid
                $deviceName = $device.DeviceFriendlyName
                $serial = $device.SerialNumber

                if ([string]::IsNullOrEmpty($uuid) -or $uuid -eq "null") {
                    Write-Host "⚠️  Skipping invalid device entry (no UUID)"
                    continue
                }

                Get-AppInfo -uuid $uuid -deviceName $deviceName -serial $serial
            }
        }
    } catch {
        Write-Host "❌ Error retrieving device info for: $id"
        Write-Host $_.Exception.Message
    }
}

Write-Host "`n✅ App data saved to: $CsvFile"
