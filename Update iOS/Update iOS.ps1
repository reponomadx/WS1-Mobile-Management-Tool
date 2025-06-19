# -------------------------------------------------------------------------------
# Script Name: Update iOS.ps1
# Purpose:     Send iOS Update (InstallASAP) command to Workspace ONE-managed devices
# Description: Prompts for one or more serial numbers and triggers an OS update
#              using Workspace ONE's "scheduleosupdate" API. Requires a valid
#              cached OAuth token (handled separately).
# -------------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
# Adjust these values for your environment
$tokenPath    = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$TokenCacheFile = $tokenPath
$TokenLifetimeSeconds = 3600  # Token cache duration
$tenantCode   = "YOUR_OMNISSA_TENANT_CODE"
$ws1EnvUrl    = "https://YOUR_OMNISSA_ENV.awmdm.com/api"

# -------------------------------
# FUNCTION: Get-WS1Token
# Purpose: Returns cached access token if still valid
# -------------------------------
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $fileAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($fileAge.TotalSeconds -lt $TokenLifetimeSeconds) {
            $cachedToken = Get-Content $TokenCacheFile | ConvertFrom-Json
            return $cachedToken.access_token
        }
    }

    Write-Host "❌ Access token is missing or expired. Please wait for the hourly renewal task or contact IT support." -ForegroundColor Red
    exit 1
}

# -------------------------------
# FUNCTION: Send-iOSUpdate
# Purpose: Sends an InstallASAP OS update command to one or more serial numbers
# -------------------------------
function Send-iOSUpdate {
    param (
        [string[]]$SerialNumbers
    )

    $url = "$ws1EnvUrl/mdm/devices/commands/bulk/scheduleosupdate?searchby=Serialnumber&installaction=InstallASAP"
    $headers = @{
        "Authorization"  = "Bearer $(Get-WS1Token)"
        "accept"         = "application/json;version=1"
        "aw-tenant-code" = $tenantCode
        "Content-Type"   = "application/json"
    }

    $body = @{
        BulkValues = @{
            Value = $SerialNumbers
        }
    } | ConvertTo-Json -Depth 3

    try {
        Write-Host "🚀 Sending OS update command to ${SerialNumbers.Count} device(s)..."
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "✅ OS update command successfully issued."
    } catch {
        Write-Host "❌ Failed to send update command: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -------------------------------
# MAIN EXECUTION
# -------------------------------
Write-Host ""
Write-Host "📲 Workspace ONE - iOS Update Utility" -ForegroundColor Cyan
$inputSerials = Read-Host "Enter one or more device serial numbers (comma-separated)"
$serials = $inputSerials.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if ($serials.Count -eq 0) {
    Write-Host "❌ No valid serial numbers entered." -ForegroundColor Red
    exit 1
}

Send-iOSUpdate -SerialNumbers $serials
