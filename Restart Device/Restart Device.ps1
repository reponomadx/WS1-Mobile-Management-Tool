# -----------------------------------------------------------------------------
# Script Name: Restart Device.ps1
# Purpose: Issue Workspace ONE soft reset (reboot) commands to one or more devices
# Description:
#   This script allows IT administrators to reboot Workspace ONE-managed devices
#   using serial numbers. Serial numbers are validated before sending a bulk
#   soft reset command to the API. Requires OAuth token authentication.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "\\CSDME1\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600
$ApiUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API/mdm/devices/commands/bulk?command=softreset&searchby=Serialnumber"
$TenantCode = "YOUR_TENANT_CODE"

# -------------------------------
# FUNCTION: Get-WS1Token
# -------------------------------
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $age = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $TokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "❌ Access token is missing or expired. Please wait for the hourly renewal task or contact IT support."
    exit 1
}

# -------------------------------
# MAIN
# -------------------------------
echo ""
Write-Host "🔄 Restart Device"

# Prompt for serial numbers
$input = Read-Host "Enter one or more 10- or 12-character serial numbers (comma-separated)"
$serials = @($input -split ',' | ForEach-Object { $_.Trim() })

# Validate
foreach ($serial in $serials) {
    if ($serial.Length -ne 10 -and $serial.Length -ne 12) {
        Write-Host "❌ Invalid serial number: $serial (must be 10 or 12 characters)"
        exit 1
    }
}

# Confirm
Write-Host "`n📋 You entered the following serial numbers:"
$serials | ForEach-Object { Write-Host "- $_" }
$confirmation = if ($serials.Count -eq 1) {
    Read-Host "⚠️ Are you sure you want to reboot this device? [y/N]"
} else {
    Read-Host "⚠️ Are you sure you want to reboot these devices? [y/N]"
}
if ($confirmation -notin @("y", "Y")) {
    Write-Host "❌ Operation canceled."
    exit 0
}

# Retrieve cached token
$AccessToken = Get-WS1Token

# Build payload
$payload = @{ BulkValues = @{ Value = $serials } } | ConvertTo-Json -Depth 3

# API call
try {
    $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
        "Content-Type"  = "application/json"
    } -Body $payload
} catch {
    Write-Host "❌ API request failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Output summary
Write-Host "`n✅ Response from Workspace ONE:"
Write-Host "- Total Devices Processed: $($response.TotalItems)"
Write-Host "- Successful Reboots: $($response.AcceptedItems)"
Write-Host "- Failed Reboots: $($response.FailedItems)"
