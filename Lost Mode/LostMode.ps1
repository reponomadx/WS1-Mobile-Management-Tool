<#
.SYNOPSIS
Enable or disable Lost Mode on Workspace ONE managed devices by serial number.

.DESCRIPTION
This script authenticates using a shared OAuth token and allows IT administrators
to remotely enable or disable Lost Mode on devices via serial number lookup. The
script validates input and uses Omnissa API calls to manage device status.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$oauthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$tokenCacheFile = "$oauthDir\ws1_token_cache.json"
$ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/api"

# -------------------------------
# Get OAuth Token from Cache
# -------------------------------
function Get-WS1Token {
    if (-Not (Test-Path $tokenCacheFile)) {
        Write-Host "❌ Token cache not found at $tokenCacheFile" -ForegroundColor Red
        exit 1
    }

    try {
        $tokenData = Get-Content $tokenCacheFile | ConvertFrom-Json
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
echo ""
Write-Host "📍 Lost Mode" -ForegroundColor Cyan
$input = Read-Host "Enter one or more 10 or 12-character serial numbers (comma-separated)"
$serials = $input -replace '\s' -split ','

foreach ($serial in $serials) {
    if ($serial.Length -ne 10 -and $serial.Length -ne 12) {
        Write-Host "❌ Invalid serial number: $serial (must be 10 or 12 characters)"
        exit 1
    }
}

Write-Host "`n📜 You entered:"
$serials | ForEach-Object { Write-Host "- $_" }
Write-Host ""

$accessToken = Get-WS1Token

$action = Read-Host "Would you like to (e)nable or (d)isable Lost Mode? [e/d]"
if ($action -ne 'e' -and $action -ne 'd') {
    Write-Host "❌ Invalid option selected."
    exit 1
}

foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up device ID for: $serial..."
    $deviceResponse = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization = "Bearer $accessToken"
        Accept        = "application/json"
    }

    $deviceId = $deviceResponse.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Failed to retrieve device ID for serial: $serial"
        continue
    }

    $lostModeUri = "$ws1EnvUrl/mdm/devices/$deviceId/lostmode"
    if ($action -eq 'e') {
        Write-Host "📳 Enabling Lost Mode for $serial..."
        $body = @{
            Message  = "This device has been locked by IT. Please return to your supervisor."
            Phone    = "0000000000"
            Footnote = "ChristianaCare IT Dept."
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $lostModeUri -Method Post -Body $body -Headers @{
            Authorization = "Bearer $accessToken"
            Accept        = "application/json"
            "Content-Type" = "application/json"
        }
        Write-Host "✅ Lost Mode enabled."
    } else {
        Write-Host "🔓 Disabling Lost Mode for $serial..."
        Invoke-RestMethod -Uri $lostModeUri -Method Delete -Headers @{
            Authorization = "Bearer $accessToken"
            Accept        = "application/json"
        }
        Write-Host "✅ Lost Mode disabled."
    }
}
