<#
.SYNOPSIS
Clears the passcode on one or more Workspace ONE managed devices.

.DESCRIPTION
This script uses a cached OAuth token to send a Clear Passcode command to 
devices in Workspace ONE UEM by serial number. The action is queued and 
executed remotely for supported devices.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$Ws1EnvUrl      = "https://YOUR_OMNISSA_ENV.awmdm.com/api"
$TenantCode     = "YOUR_TENANT_CODE"

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

Write-Host "`n🔓 Clear Device Passcode" -ForegroundColor Cyan
$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($serials.Count -eq 0) {
    Write-Host "❌ No valid serial numbers provided. Exiting."
    exit 1
}

foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up device ID for serial: $serial..."
    $deviceData = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $accessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $deviceData.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Could not find device for serial: $serial"
        continue
    }

    Write-Host "📲 Sending Clear Passcode command..."
    $response = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices/$deviceId/commands?command=ClearPasscode" -Method Post -Headers @{
        Authorization   = "Bearer $accessToken"
        Accept          = "application/json"
        "Content-Type"  = "application/json"
    }

    if ($response.errorCode -eq 0 -or !$response.errorCode) {
        Write-Host "✅ Command sent successfully for $serial"
    } else {
        Write-Host "❌ Failed to send command for $serial"
        Write-Host "📄 Error: $($response.message)"
    }
}
