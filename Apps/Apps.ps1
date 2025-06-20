<#
.SYNOPSIS
Retrieves installed applications and app assignment details for a device.

.DESCRIPTION
This script uses a cached OAuth token to authenticate with Workspace ONE and 
query installed applications on a device by serial number. Outputs details to a CSV.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "C:\Path\To\Shared\Token\ws1_token_cache.json"
$Ws1EnvUrl = "https://yourenv.awmdm.com/API"
$OutputDir = "$HOME\Downloads"
$CsvFile = "$OutputDir\device_apps.csv"

# Ensure output directory exists and prepare CSV file
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}
"" | Set-Content $CsvFile
"Device Name,Serial Number,App Name,Assignment Status,Installed Status,Installed Version,Latest UEM Action" | Add-Content $CsvFile

# -------------------------------
# FUNCTIONS
# -------------------------------

# Retrieves token from cache
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

# Retrieves app info by device UUID
function Get-AppInfo {
    param (
        [string]$uuid,
        [string]$deviceName,
        [string]$serial
    )

    Write-Host "`n📦 Installed Applications for Device: $deviceName ($serial)"
    Write-Host "----------------------------------------------"

    $apps = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/mdm/devices/$uuid/apps" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
    }

    foreach ($app in $apps.DeviceApps) {
        $line = "$deviceName,$serial,$($app.ApplicationName),$($app.AssignmentStatus),$($app.InstallStatus),$($app.InstalledVersion),$($app.LastActionOnInstall)"
        Add-Content -Path $CsvFile -Value $line
        Write-Host "$($app.ApplicationName) — $($app.InstallStatus) ($($app.InstalledVersion))"
    }
}

# -------------------------------
# MAIN
# -------------------------------

$AccessToken = Get-WS1Token

Write-Host "`n📘 Installed Apps Lookup" -ForegroundColor Cyan
$serialInput = Read-Host "Enter one or more device serial numbers (comma-separated)"
if ([string]::IsNullOrWhiteSpace($serialInput)) {
    Write-Host "❌ No serial number(s) provided. Exiting."
    exit 1
}
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up device by serial: $serial..."
    $device = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
    }

    if (-not $device.Id.Value) {
        Write-Host "❌ Device not found for serial: $serial"
        continue
    }

    $uuid = $device.Uid.Value
    $deviceName = $device.DeviceFriendlyName

    Get-AppInfo -uuid $uuid -deviceName $deviceName -serial $serial
}

Write-Host "`n✅ App data exported to: $CsvFile"
