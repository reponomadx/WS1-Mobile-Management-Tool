<#
.SYNOPSIS
Sends a restart command to one or more Workspace ONE-managed devices.

.DESCRIPTION
This script uses a shared OAuth token to locate devices by serial number 
and issues a remote restart command. The script supports bulk or single 
device actions and logs results to the console.

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
Write-Host "`n🔁 Device Restart" -ForegroundColor Cyan

$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($serials.Count -eq 0) {
    Write-Host "❌ No valid serial numbers provided. Exiting."
    exit 1
}

foreach ($serial in $serials) {
    try {
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

        Write-Host "📲 Sending restart command..."
        $response = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices/$deviceId/commands?command=RestartDevice" -Method Post -Headers @{
            Authorization   = "Bearer $accessToken"
            Accept          = "application/json"
            "Content-Type"  = "application/json"
        }

        if ($response.errorCode -eq 0 -or !$response.errorCode) {
            Write-Host "✅ Restart command sent to $serial"
        } else {
            Write-Host "❌ Failed to send restart command"
            Write-Host "📄 Error: $($response.message)"
        }
    }
    catch {
        Write-Host "❌ Exception occurred for $serial"
        Write-Host $_.Exception.Message
    }
}
