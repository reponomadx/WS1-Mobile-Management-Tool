# -----------------------------------------------------------------------------
# Script Name: InstallPurchasedApp_CLI.ps1
# Purpose: Retrieve all purchased apps and install one on a device via serial number
# Description:
#   This script queries Workspace ONE for all purchased apps, exports them to CSV,
#   prompts the user for a device serial number, and installs the selected app to that device.
#   It uses OAuth for authentication and supports error handling for common issues.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

# Path to OAuth token directory (network or local)
$OAuthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600  # Token cache duration

# Workspace ONE API endpoints (replace with actual environment if deploying)
$Ws1EnvUrl     = "https://YOUR_OMNISSA_ENV.awmdm.com"
$TokenUrl      = "https://na.uemauth.workspaceone.com/connect/token"
$ClientId      = "YOUR_CLIENT_ID"
$ClientSecret  = "YOUR_CLIENT_SECRET"
$OrgGroupUUID  = "YOUR_ORGGROUP_UUID"
$TenantCode    = "YOUR_TENANT_CODE"

# --------------------------------
# FUNCTIONS
# --------------------------------

# Returns cached access token if still valid, otherwise fetches a new one
function Get-Ws1Token {
    $now = Get-Date
    if (Test-Path $TokenCacheFile) {
        $tokenAge = ($now - (Get-Item $TokenCacheFile).LastWriteTime).TotalSeconds
        if ($tokenAge -lt $TokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "Requesting new Workspace ONE access token..."
    $response = Invoke-RestMethod -Method Post -Uri $TokenUrl -ContentType "application/x-www-form-urlencoded" -Body @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
    }

    $response | ConvertTo-Json | Set-Content -Path $TokenCacheFile
    return $response.access_token
}

# --------------------------------
# MAIN
# --------------------------------

# Get OAuth access token
$accessToken = Get-Ws1Token

Write-Host "`n📦 Retrieving all purchased apps..."

# Output file for apps
$outputCsv = "\\HOST_SERVER\MobileManagementTool\Apps\All_Purchased.csv"

# Query Workspace ONE for all purchased apps
$purchasedApps = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/api/mam/apps/purchased/search?organizationgroupuuid=$OrgGroupUUID" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json;version=1"
}

# Handle empty response
if (-not $purchasedApps.Application) {
    echo ""
    Write-Host "❌ No purchased apps returned by API."
    $purchasedApps | ConvertTo-Json -Depth 5 | Out-File "$OAuthDir\debug_apps.json"
    exit 1
}

# Export purchased app list to CSV
$purchasedApps.Application | ForEach-Object {
    [PSCustomObject]@{
        ApplicationName = $_.ApplicationName
        ApplicationSize = $_.ApplicationSize
        BundleId        = $_.BundleId
        Id              = $_.Id.Value
        Uuid            = $_.Uuid
    }
} | Export-Csv -Path $outputCsv -NoTypeInformation

# --------------------------------
# USER INPUT & INSTALL LOGIC
# --------------------------------

echo ""
Write-Host "Install App"
$serial = Read-Host "Enter the serial number of the device to install an app"

# Validate serial input
if (-not $serial) {
    Write-Host "❌ No serial number provided. Exiting script..."
    exit 1
}

# Lookup device details
$deviceInfo = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/API/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json"
}

$deviceId = $deviceInfo.Id.Value
$udid     = $deviceInfo.Udid
$mac      = $deviceInfo.MacAddress

# Exit if device not found
if (-not $deviceId) {
    Write-Host "❌ Device not found for serial: $serial"
    exit 1
}

# Display available apps
Write-Host "`n📋 Available Purchased Apps:"
$apps = Import-Csv -Path $outputCsv
for ($i = 0; $i -lt $apps.Count; $i++) {
    Write-Host "$($i + 1)) $($apps[$i].ApplicationName)"
}

# Prompt for app selection
$appSelection = Read-Host "Enter the number of the app to install"

# Validate selection input
if (-not $appSelection -or -not ($appSelection -match '^\d+$') -or [int]$appSelection -lt 1 -or [int]$appSelection -gt $apps.Count) {
    Write-Host "❌ Invalid or no app selection. Exiting script..."
    exit 1
}

# Assign selected app
$appIndex = [int]$appSelection - 1
$appId = $apps[$appIndex].Id
$appName = $apps[$appIndex].ApplicationName

echo ""
Write-Host "🚀 Installing $appName on device $serial..."

# Try install request
try {
    $installResponse = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/API/mam/apps/purchased/$appId/install" -Headers @{
        Authorization    = "Basic YOUR_BASE64_ENCODED_CREDENTIALS"
        Accept           = "application/json;version=1"
        "aw-tenant-code" = $TenantCode
        "Content-Type"   = "application/json"
    } -Body (@{
        DeviceId     = $deviceId
        Udid         = $udid
        SerialNumber = $serial
        MacAddress   = $mac
    } | ConvertTo-Json -Depth 3)

    echo ""
    Write-Host "✅ Install command issued for $appName"
}
catch {
    # Handle install error (app likely not assigned)
    try {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $responseBody = $reader.ReadToEnd() | ConvertFrom-Json

        $msg = if ($responseBody.message) { $responseBody.message } else { "Unknown error occurred." }
        $activityId = if ($responseBody.activityId) { $responseBody.activityId } else { "N/A" }

        echo ""
        Write-Host "`n❌ $appName is not assigned to the device."
    }
    catch {
        Write-Host "`n❌ $appName is not assigned to the device."
    }
}
