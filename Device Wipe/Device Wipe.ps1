<#
.SYNOPSIS
Securely wipes one or more Workspace ONE managed devices by serial number.

.DESCRIPTION
This script uses a shared OAuth token to locate devices by serial number
and remotely issues a device wipe command. The action is logged to a 
timestamped file in the user's Downloads folder for audit purposes.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$Ws1EnvUrl      = "https://YOUR_OMNISSA_ENV.awmdm.com/api"
$TenantCode     = "YOUR_TENANT_CODE"

$logFilePath = "$HOME\Downloads\WipedDevices.txt"
"" | Out-File -FilePath $logFilePath -Encoding utf8

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
Write-Host "`n💣 Device Wipe" -ForegroundColor Cyan
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
            Add-Content $logFilePath "`n$serial - ❌ Device not found"
            continue
        }

        Write-Host "📲 Sending Wipe Device command..."
        $wipeResponse = Invoke-RestMethod -Uri "$Ws1EnvUrl/mdm/devices/$deviceId/commands?command=EnterpriseWipe" -Method Post -Headers @{
            Authorization   = "Bearer $accessToken"
            Accept          = "application/json"
            "Content-Type"  = "application/json"
        }

        if ($wipeResponse.errorCode -eq 0 -or !$wipeResponse.errorCode) {
            Write-Host "✅ Wipe command sent for $serial"
            Add-Content $logFilePath "`n$serial - ✅ Wipe sent successfully"
        } else {
            Write-Host "❌ Failed to send wipe command for $serial"
            Write-Host "📄 Error: $($wipeResponse.message)"
            Add-Content $logFilePath "`n$serial - ❌ Wipe failed: $($wipeResponse.message)"
        }
    }
    catch {
        Write-Host "❌ Exception occurred for $serial"
        Write-Host $_.Exception.Message
        Add-Content $logFilePath "`n$serial - ❌ Exception: $($_.Exception.Message)"
    }
}

Write-Host "`n🗒️ Log saved to: $logFilePath"
