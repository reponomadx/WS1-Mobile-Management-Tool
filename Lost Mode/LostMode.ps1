# -----------------------------------------------------------------------------
# Script Name: LostMode.ps1
# Purpose: Enable or disable Lost Mode for Workspace ONE devices
# Description:
#   This script allows IT administrators to enable or disable Lost Mode on 
#   enrolled devices in Workspace ONE by serial number. Device details are 
#   displayed before prompting the admin for action. Lost Mode settings can 
#   include a custom message and contact number.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
# Path where OAuth token will be cached
$oauthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$tokenCacheFile = "$oauthDir\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600

# Workspace ONE environment details
$ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$lostModeApiBase = "https://YOUR_OMNISSA_ENV.awmdm.com/api/mdm/devices"
$tokenUrl = "https://na.uemauth.workspaceone.com/connect/token"
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

# -------------------------------
# FUNCTION: Get-WS1Token
# Retrieves a valid OAuth token, either from cache or via API
# -------------------------------
function Get-WS1Token {
    if (Test-Path $tokenCacheFile) {
        $age = (Get-Date) - (Get-Item $tokenCacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $tokenLifetimeSeconds) {
            return (Get-Content $tokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    # Request new token
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body @{
        grant_type    = 'client_credentials'
        client_id     = $clientId
        client_secret = $clientSecret
    } -ContentType "application/x-www-form-urlencoded"

    $response | ConvertTo-Json | Out-File $tokenCacheFile
    return $response.access_token
}

# -------------------------------
# MAIN
# -------------------------------
echo ""
Write-Host "Lost Mode"

# Prompt for device serial numbers
$input = Read-Host "Enter one or more 10 or 12-character serial numbers (comma-separated)"
$serials = $input -replace '\s' -split ','

# Validate input
foreach ($serial in $serials) {
    if ($serial.Length -ne 10 -and $serial.Length -ne 12) {
        Write-Host "❌ Invalid serial number: $serial (must be 10 or 12 characters)"
        exit 1
    }
}

# Echo back serials
Write-Host "`nYou entered:"
$serials | ForEach-Object { Write-Host "- $_" }
Write-Host ""

# Get access token
$accessToken = Get-WS1Token

# Process each device
foreach ($serial in $serials) {
    Write-Host "📋 Getting device details for $serial..."
    Write-Host ""

    # Query for device ID using serial number
    $searchResponse = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" }

    if (-not $searchResponse.Id.Value) {
        Write-Host "⚠️  No device found for $serial" -ForegroundColor Yellow
        continue
    }

    # Retrieve detailed device info
    $deviceDetail = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices/$($searchResponse.Id.Value)" -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" }

    # Display summary of device details
    $details = @(
        "📱 Device Information",
        "-----------------------------",
        "Device ID: $($deviceDetail.Id.Value)",
        "Last Seen: $($deviceDetail.LastSeen)",
        "Device Name: $($deviceDetail.DeviceFriendlyName)",
        "Serial Number: $($deviceDetail.SerialNumber)",
        "MAC Address: $($deviceDetail.MacAddress)",
        "Location Group: $($deviceDetail.LocationGroupName)",
        "User Name: $($deviceDetail.UserName)",
        "User Email: $($deviceDetail.UserEmailAddress)",
        "Model: $($deviceDetail.Model)",
        "Operating System: $($deviceDetail.OperatingSystem)",
        "Enrollment Status: $($deviceDetail.EnrollmentStatus)",
        "Last Enrolled On: $($deviceDetail.LastEnrolledOn)",
        "Ownership: $($deviceDetail.Ownership)",
        "Compliance Status: $($deviceDetail.ComplianceStatus)",
        "Last Compliance Check: $($deviceDetail.LastComplianceCheckOn)",
        ""
    )
    $details | ForEach-Object { Write-Host $_ }

    # Use UUID if available
    $uuid = if ($deviceDetail.Id.Uuid) { $deviceDetail.Id.Uuid } else { $deviceDetail.Uuid }

    # Prompt for action
    $action = Read-Host "Would you like to ENABLE or DISABLE Lost Mode for $serial? [enable/disable/skip]"
    Write-Host ""

    if ($action -eq "enable") {
        $lockMsg = Read-Host "Enter the message to display on the lock screen"
        Write-Host ""

        $body = @{ footnote = "ACME IT"; message = $lockMsg; phone_number = "123-123-4567" } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri "$lostModeApiBase/$uuid/lostmode/true" -Method Put -Headers @{
                Authorization  = "Bearer $accessToken"
                Accept         = "application/json;version=1"
                'Content-Type' = "application/json"
            } -Body $body
            Write-Host "✅ Lost Mode has been ENABLED for $serial"
        } catch {
            $msg = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -ExpandProperty message
            Write-Host "⚠️ $msg"
        }

    } elseif ($action -eq "disable") {
        $body = @{ header = "ACME IT"; message = "Lost Mode cleared."; phone_number = "IT Service Desk: 123-123-4567" } | ConvertTo-Json
        try {
            Invoke-RestMethod -Uri "$lostModeApiBase/$uuid/lostmode/false" -Method Put -Headers @{
                Authorization  = "Bearer $accessToken"
                Accept         = "application/json;version=1"
                'Content-Type' = "application/json"
            } -Body $body
            Write-Host "🚫 Lost Mode has been DISABLED for $serial"
        } catch {
            $msg = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -ExpandProperty message
            Write-Host "⚠️ $msg"
        }

    } else {
        Write-Host "⏭️ Skipped Lost Mode action for $serial."
    }

    Write-Host ""
}

Write-Host "✅ Done."
