<#
.SYNOPSIS
Clears the passcode from a locked iOS device via Workspace ONE API.

.DESCRIPTION
This script authenticates using a shared OAuth token and issues a passcode clear 
command for one or more devices by serial number. Useful for helping end users 
regain access to locked iPhones or iPads.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "C:\Path\To\Shared\Token\ws1_token_cache.json"
$Ws1EnvUrl = "https://yourenv.awmdm.com/API"
$TenantCode = "YOUR_TENANT_CODE"

# -------------------------------
# FUNCTIONS
# -------------------------------

# Retrieves cached OAuth token
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

# Sends Clear Passcode command
function Clear-Passcode {
    param (
        [string]$serial
    )

    Write-Host "`n🔓 Clearing passcode for device: $serial..."

    # Lookup device ID
    $device = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $device.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Device not found for serial: $serial"
        return
    }

    # Send clear passcode command
    $jsonBody = @{ command = "ClearPasscode" } | ConvertTo-Json
    $response = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/mdm/devices/$deviceId/commands" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "Content-Type"  = "application/json"
        "aw-tenant-code"= $TenantCode
    } -Body $jsonBody

    if ($response.errorCode -eq 0 -or !$response.errorCode) {
        Write-Host "✅ Clear Passcode command sent to $serial"
    } else {
        Write-Host "❌ Failed to send Clear Passcode for $serial"
        Write-Host "Error: $($response.message)"
    }
}

# -------------------------------
# MAIN
# -------------------------------

$AccessToken = Get-WS1Token

Write-Host "`n📘 Clear Passcode Utility" -ForegroundColor Cyan
$serialInput = Read-Host "Enter one or more device serial numbers (comma-separated)"

if ([string]::IsNullOrWhiteSpace($serialInput)) {
    Write-Host "⚠️ No serial number provided. Exiting." -ForegroundColor Yellow
    exit 1
}

$serials = $serialInput -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($serial in $serials) {
    Clear-Passcode -serial $serial
}
