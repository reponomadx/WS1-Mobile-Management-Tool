# -----------------------------------------------------------------------------
# Script Name: DeviceEventLog.ps1
# Purpose: Retrieve the 1,000 most recent Workspace ONE event log entries
# Description:
#   This script allows IT administrators to pull the latest device event logs
#   from Workspace ONE based on a provided serial number. It uses OAuth token
#   authentication and outputs results to a timestamped log file in the user's
#   Downloads folder for easy reference and audit purposes.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
$UserDownloads = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
$LogFile = Join-Path $UserDownloads "DeviceEventLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Start-Transcript -Path $LogFile -Append

$OAuthDir           = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile     = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600

$TokenUrl     = "https://na.uemauth.vmwservices.com/connect/token"
$ClientId     = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"
$TenantCode   = "YOUR_TENANT_CODE"

# -------------------------------
# TOKEN FUNCTION
# -------------------------------
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $age = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $TokenLifetimeSeconds) {
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
        Stop-Transcript
        exit 1
    }

    if (-not (Test-Path $OAuthDir)) {
        New-Item -Path $OAuthDir -ItemType Directory | Out-Null
    }

    $response | ConvertTo-Json | Set-Content $TokenCacheFile
    return $response.access_token
}

# -------------------------------
# MAIN
# -------------------------------
Write-Host "`nDevice Event Log (1000 Entries)"
$Serial = Read-Host "Enter a 10 or 12-character serial number"
if ($Serial -notmatch '^[A-Za-z0-9]{10,12}$') {
    Write-Host "❌ Invalid serial number: $Serial"
    Stop-Transcript
    exit 1
}

$AccessToken = Get-WS1Token
$EventUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/api/mdm/devices/eventlog?searchBy=Serialnumber&id=$Serial&pagesize=1000"

Write-Host "`n📋 Querying event log for serial number: $Serial"

try {
    $EventResponse = Invoke-RestMethod -Uri $EventUrl -Headers @{
        "accept"          = "application/json;version=1"
        "Authorization"   = "Bearer $AccessToken"
        "aw-tenant-code"  = $TenantCode
    } -Method Get
} catch {
    Write-Host "❌ Failed to retrieve event logs. Error: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}

# -------------------------------
# OUTPUT
# -------------------------------
if (-not $EventResponse.DeviceEventLogEntries) {
    Write-Host "⚠️  No event log entries found for serial number $Serial."
} else {
    Write-Host "`n📝 Event Log Entries:"
    $EventResponse.DeviceEventLogEntries | ForEach-Object {
        "$($_.TimeStamp)`t$($_.Severity)`t$($_.Source)`t$($_.Event)`t$($_.AdminAccount)"
    }
}
echo ""
Stop-Transcript
