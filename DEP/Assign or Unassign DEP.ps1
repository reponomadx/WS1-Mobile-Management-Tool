# -----------------------------------------------------------------------------
# Script Name: DEP_AssignUnassign.ps1
# Purpose: Assign or unassign DEP profiles in Workspace ONE using Basic Auth
# Description:
#   This script allows IT admins to assign or unassign DEP enrollment profiles 
#   to one or more Apple devices in Workspace ONE. It uses Basic Auth and supports
#   profile listing, profile lookup, and device serial-based targeting.
#   The script is intended for internal use and supports both interactive and bulk processing.
#
# This script uses basic auth. Had issues getting it to work with OAUTH at this time.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------

# Replace all placeholder values before deployment
$tenantCode       = "YOUR_TENANT_CODE"
$basicAuthHeader  = "Basic YOUR_BASIC_AUTH_HEADER"
$orgGroupUuid     = "YOUR_ORG_GROUP_UUID"
$ws1EnvUrl        = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$tmpProfileMap    = "\\HOST_SERVER\MobileManagementTool\DEP\ws1_dep_profile_map.csv"
$profileCsv       = "\\HOST_SERVER\MobileManagementTool\DEP\DEP_Profiles.csv"

# -------------------------------
# FUNCTIONS
# -------------------------------

# Look up the Workspace ONE Device ID from a given serial number
function Get-DeviceIdFromSerial($serial) {
    Write-Host "🔍 Looking up Device ID for serial: $serial..."
    $url = "$ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial"
    $response = Invoke-RestMethod -Uri $url -Headers @{ 
        "Authorization"    = $basicAuthHeader
        "accept"           = "application/json"
        "aw-tenant-code"   = $tenantCode
    } -Method Get -ErrorAction Stop
    return $response.Id.Value
}

# Fetch and export available DEP profiles to CSV
function List-DEPProfiles {
    echo ""
    Write-Host "📄 Fetching available DEP profiles..."
    $url = "$ws1EnvUrl/mdm/dep/profiles/search?organizationgroupuuid=$orgGroupUuid"
    $response = Invoke-RestMethod -Uri $url -Headers @{
        "Authorization"    = $basicAuthHeader
        "accept"           = "application/json"
        "aw-tenant-code"   = $tenantCode
    } -Method Get -ErrorAction Stop

    $response.ProfileList | ForEach-Object {
        [PSCustomObject]@{
            ProfileID    = $_.SharedMdmProfileDataId
            ProfileUUID  = $_.uuid
            ProfileName  = $_.ProfileName
        }
    } | Tee-Object -Variable profiles | Export-Csv -Path $tmpProfileMap -NoTypeInformation

    $profiles | Select-Object ProfileID, ProfileName | Export-Csv -Path $profileCsv -NoTypeInformation
    Write-Host "📁 Saved cleaned profile list to $profileCsv"
    return $profiles
}

# Assign a DEP profile to a device by serial number
function Assign-DEPProfile($serial, $profileUUID, $profileName) {
    $serialTrimmed = ($serial -replace '\s', '').Trim()
    echo ""
    Write-Host "📦 Assigning DEP profile '$profileName' to device $serialTrimmed..."
    $url = "$ws1EnvUrl/mdm/dep/profiles/$profileUUID/devices/$serialTrimmed?action=Assign"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
            "Authorization"    = $basicAuthHeader
            "accept"           = "application/json;version=1"
            "aw-tenant-code"   = $tenantCode
            "Content-Type"     = "application/json"
            "Content-Length"   = "0"
        } -ErrorAction Stop

        if ($response -and $response.errorCode) {
            Write-Host "❌ Failed to assign DEP profile."
            $global:depFailure++
        } else {
            Write-Host "✅ Successfully assigned DEP profile."
            $global:depSuccess++
        }
    } catch {
        Write-Host "❌ HTTP request failed: $_"
        $global:depFailure++
    }
}

# Unassign a DEP profile from a device by serial number
function Unassign-DEPProfile($serial, $profileUUID) {
    $serialTrimmed = ($serial -replace '\s', '').Trim()
    echo ""
    Write-Host "📦 Unassigning DEP profile from device $serialTrimmed..."
    $url = "$ws1EnvUrl/mdm/dep/profiles/$profileUUID/devices/$serialTrimmed?action=Unassign"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Put -Headers @{
            "Authorization"    = $basicAuthHeader
            "accept"           = "application/json;version=1"
            "aw-tenant-code"   = $tenantCode
            "Content-Type"     = "application/json"
            "Content-Length"   = "0"
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

# -------------------------------
# MAIN INTERACTIVE MENU
# -------------------------------

echo ""
Write-Host "DEP Assign/Unassign"
Write-Host "1. Assign DEP Profile"
Write-Host "2. Unassign DEP Profile"
Write-Host "3. Sync"
$action = Read-Host "Enter option [1-3]"
echo ""

$global:depSuccess = 0
$global:depFailure = 0

switch ($action) {
    "1" {
        $profiles = List-DEPProfiles
        $profiles | Format-Table ProfileID, ProfileName -AutoSize

        $profileId = Read-Host "Enter the DEP Profile ID to assign"
        $selectedProfile = $profiles | Where-Object { $_.ProfileID -eq $profileId }

        if (-not $selectedProfile) {
            Write-Host "❌ No matching DEP Profile found."
            break
        }

        echo ""
        Write-Host "📘 Using DEP Profile: $($selectedProfile.ProfileName)"
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

        echo ""
        Write-Host "✅ DEP Profile Assignment Summary"
        Write-Host "---------------------------------"
        Write-Host "Successfully Assigned : $depSuccess"
        Write-Host "Failed to Assign      : $depFailure"
    }
    "2" {
        $serials = (Read-Host "Enter one or more device serial numbers (comma-separated)").Split(',')
        $profileUUID = "UNASSIGN_PROFILE_UUID"  # Replace with your unassign profile UUID

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

        echo ""
        Write-Host "✅ DEP Profile Unassignment Summary"
        Write-Host "-----------------------------------"
        Write-Host "Successfully Unassigned : $depSuccess"
        Write-Host "Failed to Unassign      : $depFailure"
    }
    "3" {
        Write-Host "🔄 Sync functionality is not implemented in this version."
    }
    default {
        Write-Host "❌ Invalid option."
    }
}
