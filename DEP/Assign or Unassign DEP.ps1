# -----------------------------------------------------------------------------
# Script Name: Assign or Unassign DEP.ps1
# Purpose: Assign or unassign ADE profiles in Workspace ONE using OAuth
# Description:
#   This script allows IT admins to assign or unassign ADE enrollment profiles 
#   to one or more Apple devices in Workspace ONE. It uses OAuth and supports
#   profile listing, profile lookup, and device serial-based targeting.
#   The script is intended for internal use and supports both interactive and bulk processing.
# -----------------------------------------------------------------------------


# -------------------------------
# CONFIGURATION
# -------------------------------
$tokenUrl     = "https://na.uemauth.workspaceone.com/connect/token"
$tokenPath    = "\\YOUR_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$TokenCacheFile = $tokenPath
$TokenLifetimeSeconds = 3600  # or adjust if your tokens live longer
$tenantCode   = "YOUR_TENANT_CODE"
$orgGroupUuid = "YOUR_ORG_GROUP_UUID"
$ws1EnvUrl    = "https://YOUR_ENV.awmdm.com/api"
$tmpProfileMap = "$HOME\Downloads\ws1_dep_profile_map_oauth.csv"
$profileCsv    = "$HOME\Downloads\DEP_Profiles_oauth.csv"

# Retrieves a cached token if still valid
function Get-WS1Token {
    $now = Get-Date
    if (Test-Path $TokenCacheFile) {
        $fileAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($fileAge.TotalSeconds -lt $TokenLifetimeSeconds) {
            $cachedToken = Get-Content $TokenCacheFile | ConvertFrom-Json
            return $cachedToken.access_token
        }
    }

    Write-Host "Access token is missing or expired. Please wait for the hourly renewal task or contact IT support."
    exit 1
}

function Get-DeviceIdFromSerial($serial) {
    Write-Host "🔍 Looking up Device ID for serial: $serial..."
    $url = "$ws1EnvUrl/mdm/devices/search?serialnumber=$serial"
    try {
        $response = Invoke-RestMethod -Uri $url -Headers @{ 
            "Authorization" = "Bearer $(Get-WS1Token)"
            "accept" = "application/json"
            "aw-tenant-code" = $tenantCode
        } -Method Get -ErrorAction Stop

        $debugPath = "C:\\temp\\ws1_lookup_response.json"
        $null = New-Item -ItemType Directory -Path (Split-Path $debugPath) -Force
        $response | ConvertTo-Json -Depth 5 | Out-File -FilePath $debugPath -Force
        Write-Host "📁 WS1 response saved to $debugPath"

        if ($response.Devices -and $response.Devices.Count -gt 0 -and $response.Devices[0].Id.Value) {
            return $response.Devices[0].Id.Value
        } else {
            Write-Host "❌ No valid Device ID found in response."
            return $null
        }
    } catch {
        Write-Host "❌ Error in Get-DeviceIdFromSerial: $($_.Exception.Message)"
        return $null
    }
}

function Sync-DEPDevices {
    Write-Host "🔄 Triggering ADE Sync for Org Group: $orgGroupUuid..."
    $url = "$ws1EnvUrl/mdm/dep/groups/$orgGroupUuid/devices?action=Sync"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
            "Authorization" = "Bearer $(Get-WS1Token)"
            "accept" = "application/json;version=1"
            "aw-tenant-code" = $tenantCode
            "Content-Type" = "application/json"
            "Content-Length" = "0"
        } -ErrorAction Stop

        Write-Host "✅ ADE sync triggered successfully."
    } catch {
        Write-Host "❌ Failed to trigger ADE sync: $($_.Exception.Message)"
    }
}

function List-DEPProfiles {
    echo ""
    Write-Host "📄 Fetching available ADE profiles..."
    $url = "$ws1EnvUrl/mdm/dep/profiles/search?organizationgroupuuid=$orgGroupUuid"
    $response = Invoke-RestMethod -Uri $url -Headers @{
        "Authorization" = "Bearer $(Get-WS1Token)"
        "accept" = "application/json"
        "aw-tenant-code" = $tenantCode
    } -Method Get -ErrorAction Stop

    $response.ProfileList | ForEach-Object {
        [PSCustomObject]@{
            ProfileID = $_.SharedMdmProfileDataId
            ProfileUUID = $_.uuid
            ProfileName = $_.ProfileName
        }
    } | Tee-Object -Variable profiles | Export-Csv -Path $tmpProfileMap -NoTypeInformation

    $profiles | Select-Object ProfileID, ProfileName | Export-Csv -Path $profileCsv -NoTypeInformation
    Write-Host "📁 Saved cleaned profile list to $profileCsv"
    return $profiles
}

function Assign-DEPProfile($serial, $profileUUID, $profileName) {
    $serialTrimmed = ($serial -replace '\s', '').Trim()
    echo ""
    Write-Host "📦 Assigning ADE profile '$profileName' to device $serialTrimmed..."
    $url = "$($ws1EnvUrl)/mdm/dep/profiles/$($profileUUID)/devices/$($serialTrimmed)?action=Assign"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
            "Authorization" = "Bearer $(Get-WS1Token)"
            "accept" = "application/json;version=1"
            "aw-tenant-code" = $tenantCode
            "Content-Type" = "application/json"
            "Content-Length" = "0"
        } -ErrorAction Stop

        if ($response -and $response.errorCode) {
            Write-Host "❌ Failed to assign ADE profile."
            $global:depFailure++
        } else {
            Write-Host "✅ Successfully assigned ADE profile."
            $global:depSuccess++
        }
    } catch {
        Write-Host "❌ HTTP request failed: $_"
        $global:depFailure++
    }
}

function Unassign-DEPProfile($serial, $profileUUID) {
    $serialTrimmed = ($serial -replace '\s', '').Trim()
    echo ""
    Write-Host "📦 Unassigning ADE profile from device $serialTrimmed..."
    $url = "$($ws1EnvUrl)/mdm/dep/profiles/$($profileUUID)/devices/$($serialTrimmed)?action=Unassign"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
            "Authorization" = "Bearer $(Get-WS1Token)"
            "accept" = "application/json;version=1"
            "aw-tenant-code" = $tenantCode
            "Content-Type" = "application/json"
            "Content-Length" = "0"
        } -ErrorAction Stop

        if ($response -and $response.errorCode) {
            Write-Host "❌ Failed to unassign DEP profile."
            $global:depFailure++
        } else {
            Write-Host "✅ Successfully unassigned DEP profile."
            $global:depSuccess++
        }
    } catch {
        Write-Host "❌ HTTP request failed: $_"
        $global:depFailure++
    }
}

Write-Host ""
Write-Host "ADE Assign/Unassign"
Write-Host "1. Assign ADE Profile"
Write-Host "2. Unassign ADE Profile"
Write-Host "3. Sync"
$action = Read-Host "Enter option [1-3]"
Write-Host ""

$global:depSuccess = 0
$global:depFailure = 0

switch ($action) {
    "1" {
        $profiles = List-DEPProfiles
        $profiles | Format-Table ProfileID, ProfileName -AutoSize

        $profileId = Read-Host "Enter the ADE Profile ID to assign"
        $selectedProfile = $profiles | Where-Object { $_.ProfileID -eq $profileId }
        if (-not $selectedProfile) {
            Write-Host "❌ No matching DEP Profile found."
            break
        }

        Write-Host "📘 Using ADE Profile: $($selectedProfile.ProfileName)"
        $serials = (Read-Host "Enter one or more device serial numbers (comma-separated)").Split(',')

        foreach ($serial in $serials) {
            try {
                $deviceId = Get-DeviceIdFromSerial -serial $serial
                if ($deviceId) {
                    Write-Host "✅ Device ID resolved: $deviceId"
                    Assign-DEPProfile -serial $serial -profileUUID $selectedProfile.ProfileUUID -profileName $selectedProfile.ProfileName
                } else {
                    Write-Host "❌ Failed to retrieve device ID for serial: $serial"
                    $global:depFailure++
                }
            } catch {
                Write-Host "❌ Exception during DEP profile assignment for serial: $serial"
                $global:depFailure++
            }
        }

        Write-Host "\n✅ ADE Profile Assignment Summary"
        Write-Host "---------------------------------"
        Write-Host "Successfully Assigned : $depSuccess"
        Write-Host "Failed to Assign      : $depFailure"
    }
    "2" {
        $serials = (Read-Host "Enter one or more device serial numbers (comma-separated)").Split(',')
        # Replace this UUID with the appropriate "Unassigned" DEP profile UUID used in your environment
        $profileUUID = "REPLACE_WITH_UNASSIGN_UUID"


        foreach ($serial in $serials) {
            try {
                $deviceId = Get-DeviceIdFromSerial -serial $serial
                if ($deviceId) {
                    Write-Host "✅ Device ID resolved: $deviceId"
                    Unassign-DEPProfile -serial $serial -profileUUID $profileUUID
                } else {
                    Write-Host "❌ Failed to retrieve device ID for serial: $serial"
                    $global:depFailure++
                }
            } catch {
                Write-Host "❌ Exception during device lookup for serial: $serial"
                $global:depFailure++
            }
        }

        Write-Host "✅ ADE Profile Unassignment Summary"
        Write-Host "-----------------------------------"
        Write-Host "Successfully Unassigned : $depSuccess"
        Write-Host "Failed to Unassign      : $depFailure"
    }
    "3" {
        Sync-DEPDevices
    }
    default {
        Write-Host "❌ Invalid option."
    }
}
