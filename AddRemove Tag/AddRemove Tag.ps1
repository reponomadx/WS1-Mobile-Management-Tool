# -----------------------------------------------------------------------------
# Script Name: AddRemoveTag.ps1
# Purpose: Add or remove a Workspace ONE tag from one or more devices by serial number
# Description:
#   This script prompts the user to choose whether to apply or remove a tag,
#   allows selection from a list of tags defined in a CSV file, and processes
#   one or more serial numbers. It authenticates to the Workspace ONE API,
#   performs the tag action, and triggers a DeviceInformation command to sync.
#   A summary of the results is displayed at the end.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

# Directory where the OAuth token cache is stored
$OAuthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"

# Path to cached access token file
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"

# Token validity duration in seconds
$TokenLifetimeSeconds = 3600

# Base Workspace ONE API URL (update with actual environment hostname)
$WS1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com/API"

# OAuth token endpoint
$TokenUrl = "https://na.uemauth.vmwservices.com/connect/token"

# Workspace ONE client credentials (replace placeholders with actual values)
$ClientId = "YOUR OMNISSA CLIENT ID"
$ClientSecret = "YOUR OMNISSA CLIENT SECRET"
$TenantCode = "YOUR OMNISSA CLIENT CODE"

# Path to CSV file containing tag IDs and names
$CsvFile = "\\HOST_SERVER\MobileManagementTool\AddRemove Tag\tags.csv"

# --------------------------------
# FUNCTIONS
# --------------------------------

# Retrieves and caches a Workspace ONE API token (if not already valid)
function Get-WS1Token {
    $now = Get-Date
    if (Test-Path $TokenCacheFile) {
        $lastModified = (Get-Item $TokenCacheFile).LastWriteTime
        if ((New-TimeSpan -Start $lastModified -End $now).TotalSeconds -lt $TokenLifetimeSeconds) {
            # Load token from cache if still valid
            $global:AccessToken = (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
            return
        }
    }

    echo ""
    Write-Host "🔐 Requesting new Workspace ONE access token..."

    # Request new token using client credentials grant
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $TokenUrl -Body @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    } -ContentType "application/x-www-form-urlencoded"

    # Save token to cache and assign to global variable
    $tokenResponse | ConvertTo-Json | Set-Content $TokenCacheFile
    $global:AccessToken = $tokenResponse.access_token

    if (-not $AccessToken) {
        Write-Host "❌ Failed to obtain access token. Exiting."
        exit 1
    }
}

# Sends an API request to apply a tag to a device by its ID
function Apply-TagToDevice($deviceId, $tagId, $serial) {
    echo ""
    Write-Host "🏷️  Applying tag $tagId to device $serial..."

    $body = @{ BulkValues = @{ Value = @($deviceId) } } | ConvertTo-Json -Depth 3

    $response = Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/tags/$tagId/adddevices" -Method Post -Headers @{
        Authorization   = "Bearer $AccessToken"
        "aw-tenant-code"= $TenantCode
        Accept          = "application/json;version=1"
        "Content-Type"  = "application/json"
    } -Body $body

    return $response
}

# Sends an API request to remove a tag from a device by its ID
function Remove-TagFromDevice($deviceId, $tagId, $serial) {
    echo ""
    Write-Host "🚫 Removing tag $tagId from device $serial..."

    $body = @{ BulkValues = @{ Value = @($deviceId) } } | ConvertTo-Json -Depth 3

    $response = Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/tags/$tagId/removedevices" -Method Post -Headers @{
        Authorization   = "Bearer $AccessToken"
        "aw-tenant-code"= $TenantCode
        Accept          = "application/json;version=1"
        "Content-Type"  = "application/json"
    } -Body $body

    return $response
}

# Sends a DeviceInformation command to force a sync after tag changes
function Send-DeviceInformationCommand($deviceId, $serial) {
    echo ""
    Write-Host "📡 Requesting Device Information for $serial..."

    $response = Invoke-RestMethod -Method Post -Uri "$WS1EnvUrl/mdm/devices/$deviceId/commands?command=DeviceInformation" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "Content-Type"  = "application/json"
    }

    if ($response.errorCode -eq 0 -or !$response.errorCode) {
        Write-Host "✅ Command Sent Successfully"
    } else {
        Write-Host "❌ Command Failed"
        Write-Host "Error Code : $($response.errorCode)"
        Write-Host "Message    : $($response.message)"

        # Log errors for auditing and troubleshooting
        Add-Content -Path "$OAuthDir\device_command_errors.log" -Value "[$(Get-Date)] Device ID: $deviceId - Error $($response.errorCode): $($response.message)"
        Write-Host "📝 Logged error"
    }
}

# --------------------------------
# MAIN LOGIC
# --------------------------------

# Authenticate and obtain Workspace ONE token
Get-WS1Token

echo ""
Write-Host "Add/Remove Tag"

# Prompt user for action mode (add/remove)
$tagMode = Read-Host "Would you like to (a)dd or (r)emove a tag? [a/r]"
if ($tagMode -ne 'a' -and $tagMode -ne 'r') {
    Write-Host "❌ Invalid mode selected. Exiting."
    exit 1
}

# Load available tags from CSV file
$tags = Import-Csv $CsvFile
for ($i = 0; $i -lt $tags.Count; $i++) {
    Write-Host "$($i+1)) ID: $($tags[$i].Id) - $($tags[$i].TagName)"
}

# Prompt user to select a tag number from the list
$choice = Read-Host "Select a tag number"
$tagId = $tags[$choice - 1].Id

echo ""

# Prompt for one or more serial numbers, comma-separated
$serialInput = Read-Host "Enter one or more device serial numbers (comma-separated)"
if ([string]::IsNullOrWhiteSpace($serialInput) -or $serialInput -match '^[,\s]*$') {
    Write-Host "❌ No valid serial number(s) provided. Aborting."
    exit 1
}

# Sanitize and split serials into an array
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($serials.Count -eq 0) {
    Write-Host "❌ All serials were empty after trimming. Aborting."
    exit 1
}

# Initialize counters for reporting
$TagTotal = 0; $TagAccepted = 0; $TagFailed = 0; $TagFaults = 0

# Loop over each serial number and process tag operation
foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up Device ID for serial: $serial..."

    # Retrieve device ID based on serial number
    $deviceData = Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $deviceData.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Failed to retrieve device ID for serial: $serial"
        continue
    }

    Write-Host "✅ Device ID resolved: $deviceId"

    # Apply or remove the tag based on user choice
    if ($tagMode -eq 'a') {
        $result = Apply-TagToDevice $deviceId $tagId $serial
    } else {
        $result = Remove-TagFromDevice $deviceId $tagId $serial
    }

    # Aggregate results for reporting
    $TagTotal += $result.TotalItems
    $TagAccepted += $result.AcceptedItems
    $TagFailed += $result.FailedItems
    $TagFaults += $result.Faults.Fault.Count

    # Request device info to trigger sync
    Send-DeviceInformationCommand $deviceId $serial
}

# Display final summary report
Write-Host "`n✅ Tag Operation Summary"
Write-Host "--------------------------"
Write-Host "Total Devices Processed : $TagTotal"
if ($tagMode -eq 'a') {
    Write-Host "🎇 Successfully Tagged    : $TagAccepted"
    Write-Host "❌ Failed to Tag          : $TagFailed"
} else {
    Write-Host "🎇 Successfully Untagged  : $TagAccepted"
    Write-Host "❌ Failed to Untag        : $TagFailed"
}
Write-Host "⚠️ Faults                  : $(if ($TagFaults -eq 0) {'None'} else { "$TagFaults faults" })"
