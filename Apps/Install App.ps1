# -----------------------------------------------------------------------------
# Script Name: Install App.ps1
# Purpose: Retrieve all purchased apps and install one on a device via serial number
# Description:
#   This script queries Workspace ONE for all purchased apps, exports them to CSV,
#   prompts the user for a device serial number, and installs the selected app to that device.
#   It uses a cached OAuth token for authentication.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

$OAuthDir        = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile  = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600

$Ws1EnvUrl     = "https://YOUR_OMNISSA_ENV.awmdm.com"
$OrgGroupUUID  = "YOUR_ORGGROUP_UUID"
$TenantCode    = "YOUR_TENANT_CODE"

# --------------------------------
# FUNCTIONS
# --------------------------------

function Get-Ws1Token {
    $now = Get-Date
    if (Test-Path $TokenCacheFile) {
        $tokenAge = ($now - (Get-Item $TokenCacheFile).LastWriteTime).TotalSeconds
        if ($tokenAge -lt $TokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "Access token is missing or expired. Please wait for the hourly renewal task or contact IT support."
    exit 1
}

# --------------------------------
# MAIN
# --------------------------------

$accessToken = Get-Ws1Token

Write-Host "`nRetrieving all purchased apps..."
$outputCsv = "$HOME\Downloads\All_Purchased.csv"

$purchasedApps = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/api/mam/apps/purchased/search?organizationgroupuuid=$OrgGroupUUID" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json;version=1"
}

if (-not $purchasedApps.Application) {
    Write-Host "No purchased apps returned by API."
    $purchasedApps | ConvertTo-Json -Depth 5 | Out-File "$OAuthDir\debug_apps.json"
    exit 1
}

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
# USER INPUT
# --------------------------------

echo ""
Write-Host "Install App"
$serial = Read-Host "Enter the serial number of the device to install an app"

if (-not $serial) {
    Write-Host "No serial number provided. Exiting script..."
    exit 1
}

$deviceInfo = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/API/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json"
}

$deviceId = $deviceInfo.Id.Value
$udid     = $deviceInfo.Udid
$mac      = $deviceInfo.MacAddress

if (-not $deviceId) {
    Write-Host "Device not found for serial: $serial"
    exit 1
}

# --------------------------------
# APP SELECTION
# --------------------------------

Write-Host "`nAvailable Purchased Apps:"
$apps = Import-Csv -Path $outputCsv
for ($i = 0; $i -lt $apps.Count; $i++) {
    Write-Host "$($i + 1)) $($apps[$i].ApplicationName)"
}

$appSelection = Read-Host "Enter the number of the app to install"

if (-not $appSelection -or -not ($appSelection -match '^\d+$') -or [int]$appSelection -lt 1 -or [int]$appSelection -gt $apps.Count) {
    Write-Host "Invalid or no app selection. Exiting script..."
    exit 1
}

$appIndex = [int]$appSelection - 1
$appId    = $apps[$appIndex].Id
$appName  = $apps[$appIndex].ApplicationName

Write-Host ""
Write-Host "Installing $appName on device $serial..."

# --------------------------------
# INSTALL LOGIC
# --------------------------------

try {
    $installResponse = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/API/mam/apps/purchased/$appId/install" -Headers @{
        Authorization    = "Bearer $accessToken"
        Accept           = "application/json;version=1"
        "aw-tenant-code" = $TenantCode
        "Content-Type"   = "application/json"
    } -Body (@{
        DeviceId     = $deviceId
        Udid         = $udid
        SerialNumber = $serial
        MacAddress   = $mac
    } | ConvertTo-Json -Depth 3)

    Write-Host ""
    Write-Host "✅ Install command issued for $appName"
}
catch {
    Write-Host "`n❌ $appName is not assigned to the device."
}
