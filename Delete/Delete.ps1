# -----------------------------------------------------------------------------
# Script Name: DeleteDevices.ps1
# Purpose: Look up and optionally delete one or more devices in Workspace ONE by serial number
# Description:
#   This script accepts a list of device serial numbers, retrieves their details
#   from Workspace ONE via the API, logs the results, and gives the user the option
#   to delete them. OAuth is used for authentication with token caching.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

# OAuth and API configuration
$OAuthDir       = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600

# Workspace ONE environment details (replace placeholders for deployment)
$WS1EnvUrl    = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$TokenUrl     = "https://na.uemauth.workspaceone.com/connect/token"
$ClientId     = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"
$TenantCode   = "YOUR_TENANT_CODE"

# Output directory and file
$OutputDir  = "\\HOST_SERVER\MobileManagementTool\Delete"
$OutputFile = "$HOME\Downloads\Deleted Devices.txt"

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Clear previous output file if it exists
Clear-Content -Path $OutputFile -ErrorAction SilentlyContinue

# --------------------------------
# FUNCTIONS
# --------------------------------

# Retrieves a cached token if valid, or requests a new one
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
        exit 1
    }

    if (-not (Test-Path $OAuthDir)) {
        New-Item -ItemType Directory -Path $OAuthDir | Out-Null
    }

    $response | ConvertTo-Json | Set-Content $TokenCacheFile
    return $response.access_token
}

# --------------------------------
# MAIN
# --------------------------------

echo ""
Write-Host "Delete Device(s)"

# Prompt for input and sanitize
$Input = Read-Host "Enter one or more 10- or 12-character serial numbers (comma-separated)"
$Serials = $Input -split ',' | ForEach-Object { $_.Trim() }

# Validate serials
foreach ($serial in $Serials) {
    if ($serial -notmatch '^[A-Za-z0-9]{10,12}$') {
        Write-Host "❌ Invalid serial number: $serial (must be exactly 10 or 12 characters)" -ForegroundColor Red
        exit 1
    }

    if ($serial -ieq "HUBNOSERIAL") {
        Write-Host "🚫 The serial number '$serial' is a placeholder used by Android devices." -ForegroundColor Yellow
        Write-Host "❌ Device deletion is not supported for Android devices at this time." -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nYou entered the following identifiers:"
$Serials | ForEach-Object { Write-Host "- $_" }
Write-Host ""

# Get API token
$AccessToken = Get-WS1Token
$DeviceMap = @{}

Write-Host "📋 Retrieving device details from Workspace ONE..."

# Retrieve details for each device
foreach ($serial in $Serials) {
    $url = "$WS1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial"
    $response = Invoke-RestMethod -Uri $url -Headers @{
        "Authorization" = "Bearer $AccessToken"
        "Accept"        = "application/json"
    } -Method Get

    if ($response.Id.Value) {
        $DeviceId = $response.Id.Value
        $DeviceMap[$serial] = $DeviceId

        # Build readable summary
        $fields = @(
            "📱 Device Information",
            "-----------------------------",
            "Device ID: $($response.Id.Value)",
            "Last Seen: $($response.LastSeen)",
            "Device Name: $($response.DeviceFriendlyName)",
            "Serial Number: $($response.SerialNumber)",
            "MAC Address: $($response.MacAddress)",
            "Location Group: $($response.LocationGroupName)",
            "User Name: $($response.UserName)",
            "User Email: $($response.UserEmailAddress)",
            "Model: $($response.Model)",
            "Operating System: $($response.OperatingSystem)",
            "Enrollment Status: $($response.EnrollmentStatus)",
            "Last Enrolled On: $($response.LastEnrolledOn)",
            "Ownership: $($response.Ownership)",
            "Compliance Status: $($response.ComplianceStatus)",
            "Last Compliance Check: $($response.LastComplianceCheckOn)",
            ""
        )
        $fields | Tee-Object -FilePath $OutputFile -Append
    }
    else {
        Write-Host "⚠️ No device found for serial: $serial"
    }
}

Write-Host "`n📝 Results saved to $OutputFile`n"

# --------------------------------
# PROMPT FOR DELETION
# --------------------------------

$confirm = Read-Host "❗ Would you like to delete the devices listed above? (y/n)"
if ($confirm -match '^[Yy]$') {
    Write-Host "`n🗑️ Preparing to delete devices..."

    foreach ($pair in $DeviceMap.GetEnumerator()) {
        $serial = $pair.Key
        $deviceId = $pair.Value

        $deleteUrl = "$WS1EnvUrl/mdm/devices/$deviceId"
        Invoke-RestMethod -Uri $deleteUrl -Headers @{
            "Authorization"  = "Bearer $AccessToken"
            "accept"         = "application/json;version=1"
            "aw-tenant-code" = $TenantCode
        } -Method Delete -ErrorAction SilentlyContinue | Out-Null

        Write-Host "✅ Deleted device: $serial (Device ID: $deviceId)"
    }
}
else {
    Write-Host "🛑 Skipping device deletion."
}
