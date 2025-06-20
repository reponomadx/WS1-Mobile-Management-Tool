<#
.SYNOPSIS
Exports installed profiles from one or more Workspace ONE devices.

.DESCRIPTION
This script uses a shared OAuth token and allows IT administrators to 
retrieve and export installed MDM profiles from Workspace ONE-managed 
devices by serial number. Output is written to a CSV file in the user's 
Downloads folder.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$Ws1EnvUrl      = "https://YOUR_OMNISSA_ENV.awmdm.com/api"
$TenantCode     = "YOUR_TENANT_CODE"

$outputFile = "$HOME\Downloads\device_profiles.csv"
"" | Set-Content -Path $outputFile

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
# MAIN
# -------------------------------
$accessToken = Get-WS1Token
Write-Host "`n📂 Installed Profiles Export" -ForegroundColor Cyan

$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($serials.Count -eq 0) {
    Write-Host "❌ No valid serial numbers provided. Exiting."
    exit 1
}

Add-Content -Path $outputFile -Value "Device Name,Serial Number,Profile Name,Installed Version,Assignment Type"

foreach ($serial in $serials) {
    try {
        Write-Host "`n🔍 Looking up device ID for: $serial"
        $deviceData = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
            Authorization   = "Bearer $accessToken"
            Accept          = "application/json"
            "aw-tenant-code"= $TenantCode
        }

        $deviceId = $deviceData.Id.Value
        $deviceName = $deviceData.DeviceFriendlyName
        if (-not $deviceId) {
            Write-Host "❌ Device not found for serial: $serial"
            continue
        }

        $profileData = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices/$deviceId/profiles" -Headers @{
            Authorization   = "Bearer $accessToken"
            Accept          = "application/json"
        }

        if ($profileData.DeviceProfiles.Count -eq 0) {
            Write-Host "ℹ️ No profiles found for $serial"
            continue
        }

        foreach ($profile in $profileData.DeviceProfiles) {
            $line = "$deviceName,$serial,$($profile.ProfileName),$($profile.InstalledProfileVersion),$($profile.AssignmentType)"
            Add-Content -Path $outputFile -Value $line
        }

        Write-Host "✅ Profiles exported for $serial"
    }
    catch {
        Write-Host "❌ Error retrieving profiles for $serial"
        Write-Host $_.Exception.Message
    }
}

Write-Host "`n🗒️ Output saved to $outputFile"
