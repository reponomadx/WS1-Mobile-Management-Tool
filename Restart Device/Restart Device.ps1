# -----------------------------------------------------------------------------
# Script Name: Restart-Device.ps1
# Purpose: Issue Workspace ONE soft reset (reboot) commands to one or more devices
# Description:
#   This script allows IT administrators to reboot Workspace ONE-managed devices
#   using serial numbers. Serial numbers are validated before sending a bulk
#   soft reset command to the API. Requires OAuth token authentication.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
# Local token and working directory paths (update for your environment)
$basePath = "\\HOST_SERVER\MobileManagementTool\Restart Device"
$tokenCacheFile = "\\HOST_SERVER\MobileManagementTool\OAUTH Token\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600

# Workspace ONE API endpoints and credentials
$ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$apiUrl = "$ws1EnvUrl/mdm/devices/commands/bulk?command=softreset&searchby=Serialnumber"

$tokenUrl = "https://na.uemauth.workspaceone.com/connect/token"
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

# Ensure token cache directory exists
if (-not (Test-Path $basePath)) {
    New-Item -ItemType Directory -Path $basePath -Force | Out-Null
}

# -------------------------------
# FUNCTION: Get-WS1Token
# Retrieves a valid OAuth token (uses cached token if still valid)
# -------------------------------
function Get-WS1Token {
    $now = Get-Date
    $cacheExists = Test-Path $tokenCacheFile

    if ($cacheExists) {
        $cacheAge = ($now - (Get-Item $tokenCacheFile).LastWriteTime).TotalSeconds
        if ($cacheAge -lt $tokenLifetimeSeconds) {
            $tokenData = Get-Content $tokenCacheFile | ConvertFrom-Json
            return $tokenData.access_token
        }
    }

    Write-Host "🔐 Requesting new Workspace ONE access token..."

    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
    }

    $response | ConvertTo-Json -Depth 10 | Out-File $tokenCacheFile -Encoding utf8
    return $response.access_token
}

# -------------------------------
# MAIN
# -------------------------------
echo ""
Write-Host "🔄 Restart Device"

# Prompt for serial numbers
$input = Read-Host "Enter one or more 10- or 12-character serial numbers (comma-separated)"

# Clean and split input
$serials = @($input -split ',' | ForEach-Object { $_.Trim() })

# Validate format of serial numbers
foreach ($serial in $serials) {
    if ($serial.Length -ne 10 -and $serial.Length -ne 12) {
        Write-Host "❌ Invalid serial number: $serial (must be 10 or 12 characters)"
        exit 1
    }
}

# Show what will be processed
echo ""
Write-Host "`n📋 You entered the following serial numbers:"
$serials | ForEach-Object { Write-Host "- $_" }

# Confirmation prompt
$confirmation = if ($serials.Count -eq 1) {
    Read-Host "⚠️ Are you sure you want to reboot this device? [y/N]"
} else {
    Read-Host "⚠️ Are you sure you want to reboot these devices? [y/N]"
}
if ($confirmation -notin @("y", "Y")) {
    Write-Host "❌ Operation canceled."
    exit 0
}

# Get OAuth token
$accessToken = Get-WS1Token

# Construct JSON payload for reboot
$payload = @{
    BulkValues = @{
        Value = @($serials)
    }
} | ConvertTo-Json -Depth 10

# Submit reboot request to API
try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
        Authorization  = "Bearer $accessToken";
        Accept         = "application/json";
        "Content-Type" = "application/json"
    } -Body $payload
} catch {
    Write-Host "❌ API request failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Display API response summary
echo ""
Write-Host "`n✅ Response from Workspace ONE:"
Write-Host "- Total Devices Processed: $($response.TotalItems)"
Write-Host "- Successful Reboots: $($response.AcceptedItems)"
Write-Host "- Failed Reboots: $($response.FailedItems)"
