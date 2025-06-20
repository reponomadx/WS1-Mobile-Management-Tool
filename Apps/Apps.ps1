<#
.SYNOPSIS
Retrieves installed applications from Workspace ONE devices.

.DESCRIPTION
This script uses a shared OAuth token to query Workspace ONE UEM and retrieve 
installed app data from devices using serial numbers or user IDs. Results are 
written to a CSV file in the user's Downloads folder and displayed in the console.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$OAuthDir        = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile  = "$OAuthDir\ws1_token_cache.json"
$Ws1EnvUrl       = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$TokenUrl        = "https://na.uemauth.workspaceone.com/connect/token"

$OutputDir       = "$HOME\Downloads"
$CsvFile         = "$OutputDir\device_apps.csv"

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

"" | Set-Content $CsvFile
"Device Name,Serial Number,App Name,Assignment Status,Installed Status,Installed Version,Latest UEM Action" | Add-Content $CsvFile

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
    }
    catch {
        Write-Host "❌ Failed to parse token cache." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# -------------------------------
# Helper: Get Installed Apps
# -------------------------------
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
            "Authorization" = "Bearer $accessToken"
            "Accept"        = "application/json;version=1"
        }

        if (-not $appResponse.app_items) {
            Write-Host "No app data found."
            return
        }

        foreach ($app in $appResponse.app_items) {
            Write-Host "• $($app.name)"
            Write-Host "   - Assigned: $($app.assignment_status)"
            Write-Host "   - Installed: $($app.installed_status)"
            Write-Host "   - Installed Version: $($app.installed_version)"
            Write-Host "   - Action: $($app.latest_uem_action)"

            "$deviceName,$serial,$($app.name),$($app.assignment_status),$($app.installed_status),$($app.installed_version),$($app.latest_uem_action)" |
                Add-Content -Path $CsvFile
        }
    } catch {
        Write-Host "❌ Error retrieving apps for $deviceName ($serial)"
        Write-Host $_.Exception.Message
    }
}

# -------------------------------
# MAIN
# -------------------------------
Write-Host "`n📋 Apps (Query)" -ForegroundColor Cyan
Write-Host "Choose search type:"
Write-Host "1. Serial Number"
Write-Host "2. User ID"
$searchOption = Read-Host "Enter option [1-2]"

$apiMode = ""
$identifiers = @()

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

$accessToken = Get-WS1Token
Write-Host "`n🔍 Retrieving device details from Workspace ONE..."

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
