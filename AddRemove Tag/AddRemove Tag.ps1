<#
.SYNOPSIS
Adds or removes Workspace ONE tags from devices using serial numbers.

.DESCRIPTION
This script authenticates using a cached OAuth token and allows IT admins to apply or remove tags 
from one or more devices by serial number. It also sends a DeviceInformation command after each change.
Intended for internal use only from a trusted environment.

.VERSION
v1.3.0
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$TokenCacheFile = "C:\Path\To\Shared\Token\ws1_token_cache.json"
$WS1EnvUrl = "https://yourenv.awmdm.com/API"
$TenantCode = "YOUR_TENANT_CODE"
$CsvFile = "$HOME\Downloads\ws1_tags.csv"

# -------------------------------
# FUNCTIONS
# -------------------------------

# Retrieves a cached OAuth token
function Get-WS1Token {
    if (-Not (Test-Path $TokenCacheFile)) {
        Write-Host "❌ Token cache not found at $TokenCacheFile" -ForegroundColor Red
        exit 1
    }

    try {
        $tokenData = Get-Content $TokenCacheFile | ConvertFrom-Json
        return $tokenData.access_token
    } catch {
        Write-Host "❌ Failed to parse token cache." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# Applies the selected tag to the device
function Apply-TagToDevice($deviceId, $tagId, $serial) {
    Write-Host "`n🏷️  Applying tag $tagId to device $serial..."
    $body = @{ BulkValues = @{ Value = @($deviceId) } } | ConvertTo-Json -Depth 3
    return Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/tags/$tagId/adddevices" -Method Post -Headers @{
        Authorization    = "Bearer $AccessToken"
        "aw-tenant-code" = $TenantCode
        Accept           = "application/json;version=1"
        "Content-Type"   = "application/json"
    } -Body $body
}

# Removes the selected tag from the device
function Remove-TagFromDevice($deviceId, $tagId, $serial) {
    Write-Host "`n🚫 Removing tag $tagId from device $serial..."
    $body = @{ BulkValues = @{ Value = @($deviceId) } } | ConvertTo-Json -Depth 3
    return Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/tags/$tagId/removedevices" -Method Post -Headers @{
        Authorization    = "Bearer $AccessToken"
        "aw-tenant-code" = $TenantCode
        Accept           = "application/json;version=1"
        "Content-Type"   = "application/json"
    } -Body $body
}

# Sends a DeviceInformation command after tag change
function Send-DeviceInformationCommand($deviceId, $serial) {
    Write-Host "`n📡 Requesting Device Information for $serial..."
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
    }
}

# -------------------------------
# MAIN SCRIPT
# -------------------------------

$AccessToken = Get-WS1Token

Write-Host "`n📘 Add/Remove Tag Utility" -ForegroundColor Cyan
$tagMode = Read-Host "Would you like to (a)dd or (r)emove a tag? [a/r]"
if ($tagMode -ne 'a' -and $tagMode -ne 'r') {
    Write-Host "❌ Invalid mode selected. Exiting."
    exit 1
}

# Load available tags from CSV
$tags = Import-Csv $CsvFile
for ($i = 0; $i -lt $tags.Count; $i++) {
    Write-Host "$($i+1)) ID: $($tags[$i].Id) - $($tags[$i].TagName)"
}

# Prompt user to select a tag
$choice = Read-Host "Select a tag number"
$tagId = $tags[$choice - 1].Id

# Prompt for device serials
$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
if ([string]::IsNullOrWhiteSpace($serialInput)) {
    Write-Host "❌ No valid serial number(s) provided. Aborting."
    exit 1
}
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

if ($serials.Count -eq 0) {
    Write-Host "❌ All serials were empty after trimming. Aborting."
    exit 1
}

# Counters for summary
$TagTotal = 0; $TagAccepted = 0; $TagFailed = 0; $TagFaults = 0

foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up Device ID for serial: $serial..."
    $deviceData = Invoke-RestMethod -Uri "$WS1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $AccessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $deviceData.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Could not resolve device ID for: $serial"
        continue
    }

    Write-Host "✅ Device ID: $deviceId"

    # Apply or remove the tag
    $result = if ($tagMode -eq 'a') {
        Apply-TagToDevice $deviceId $tagId $serial
    } else {
        Remove-TagFromDevice $deviceId $tagId $serial
    }

    $TagTotal += $result.TotalItems
    $TagAccepted += $result.AcceptedItems
    $TagFailed += $result.FailedItems
    $TagFaults += ($result.Faults.Fault.Count -as [int])
    
    Send-DeviceInformationCommand $deviceId $serial
}

# Final summary
Write-Host "`n✅ Tag Operation Summary"
Write-Host "--------------------------"
Write-Host "Total Devices Processed : $TagTotal"
Write-Host "Successfully Updated     : $TagAccepted"
Write-Host "❌ Failed                : $TagFailed"
Write-Host "⚠️ Faults                : $(if ($TagFaults -eq 0) {'None'} else { "$TagFaults faults" })"
