<#
.SYNOPSIS
Deletes one or more devices from Workspace ONE using serial numbers.

.DESCRIPTION
This script authenticates using a shared OAuth token and deletes devices from 
Workspace ONE UEM by serial number. It validates serials and logs each deletion.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "C:\Path\To\Shared\Token\ws1_token_cache.json"
$WS1EnvUrl      = "https://yourenv.awmdm.com/API"
$TenantCode     = "YOUR_TENANT_CODE"
$OutputFile     = "$HOME\Downloads\Deleted Devices.txt"

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

# Deletes a single device by device ID
function Delete-DeviceById {
    param (
        [string]$deviceId,
        [string]$serial
    )

    $response = Invoke-RestMethod -Method Delete -Uri "$WS1EnvUrl/mdm/devices/$deviceId" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    if ($response.Status -eq "Success" -or !$response.Status) {
        Write-Host "🗑️  Successfully deleted device: $serial"
        Add-Content -Path $OutputFile -Value "$serial"
    } else {
        Write-Host "❌ Failed to delete device: $serial"
        Write-Host "Message: $($response.message)"
    }
}

# -------------------------------
# MAIN
# -------------------------------

$AccessToken = Get-WS1Token

Write-Host "`n📘 Delete Device(s)" -ForegroundColor Cyan
$Input = Read-Host "Enter one or more 10- or 12-character serial numbers (comma-separated)"
$Serials = $Input -split ',' | ForEach-Object { $_.Trim() }

foreach ($serial in $Serials) {
    if ($serial -notmatch '^[A-Za-z0-9]{10,12}$') {
        Write-Host "❌ Invalid serial number: $serial (must be exactly 10 or 12 characters)" -ForegroundColor Red
        continue
    }

    Write-Host "`n🔍 Looking up device ID for serial: $serial..."
    $device = Invoke-RestMethod -Method Get -Uri "$WS1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $device.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Device not found for serial: $serial"
        continue
    }

    Delete-DeviceById -deviceId $deviceId -serial $serial
}

Write-Host "`n✅ Deletion complete. Log saved to: $OutputFile"
