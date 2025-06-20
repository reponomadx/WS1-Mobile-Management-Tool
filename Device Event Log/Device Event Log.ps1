<#
.SYNOPSIS
Retrieves the 1000 most recent device events for a given serial number.

.DESCRIPTION
This script authenticates with Workspace ONE using a shared OAuth token and fetches 
the latest event log data for the specified device serial number. Results are saved 
to the user’s Downloads folder as a timestamped `.log` file.

.VERSION
v1.3.0
#>

# --------------------------------
# CONFIGURATION
# --------------------------------
$UserDownloads = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
$LogFile = Join-Path $UserDownloads "DeviceEventLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Start-Transcript -Path $LogFile -Append

$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$TenantCode     = "YOUR_OMNISSA_TENANT_CODE"
$ws1EnvUrl      = "https://YOUR_OMNISSA_ENV.awmdm.com/api"

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

# --------------------------------
# MAIN
# --------------------------------
Write-Host "`n📜 Device Event Log (1000 Entries)" -ForegroundColor Cyan
$Serial = Read-Host "Enter a 10 or 12-character serial number"
if ($Serial -notmatch '^[A-Za-z0-9]{10,12}$') {
    Write-Host "❌ Invalid serial number: $Serial"
    Stop-Transcript
    exit 1
}

$AccessToken = Get-WS1Token

# Get Device ID
Write-Host "🔍 Looking up Device ID for serial: $Serial"
$searchUrl = "$ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$Serial"
$device = Invoke-RestMethod -Uri $searchUrl -Headers @{
    Authorization   = "Bearer $AccessToken"
    Accept          = "application/json"
    "aw-tenant-code"= $TenantCode
}

if (-not $device.Id.Value) {
    Write-Host "❌ Device not found for serial: $Serial"
    Stop-Transcript
    exit 1
}

$deviceId = $device.Id.Value
Write-Host "✅ Device ID: $deviceId"

# Fetch Events
$eventsUrl = "$ws1EnvUrl/mdm/devices/$deviceId/events"
$events = Invoke-RestMethod -Uri $eventsUrl -Headers @{
    Authorization   = "Bearer $AccessToken"
    Accept          = "application/json"
    "aw-tenant-code"= $TenantCode
}

Write-Host "`n📄 Event Log Output"
Write-Host "----------------------"

foreach ($event in $events | Select-Object -First 1000) {
    $line = "$($event.EventTime) [$($event.EventType)] - $($event.EventData)"
    Write-Host $line
    $line | Out-File -FilePath $LogFile -Append
}

Write-Host "`n🗘 Results saved to $LogFile"
Stop-Transcript
