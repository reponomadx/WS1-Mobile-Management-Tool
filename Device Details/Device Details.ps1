# -----------------------------------------------------------------------------
# Script Name: Device Details.ps1
# Purpose: Lookup Workspace ONE device details by serial number or user ID
# Description:
#   This script allows IT administrators to retrieve key device information from
#   Workspace ONE using either serial numbers or user IDs. It includes support for
#   Smart Group and Tag lookups, and optionally allows querying devices for fresh
#   data via the DeviceInformation or DeviceQuery command.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------
$basePath = "\\HOST_SERVER\MobileManagementTool\Device Details"
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$tokenLifetimeSeconds = 3600

$ws1EnvUrl     = "https://YOUR_OMNISSA_ENV.awmdm.com/API"

New-Item -ItemType Directory -Force -Path $basePath | Out-Null

# -------------------------------
# TOKEN FUNCTION
# -------------------------------
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $age = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $tokenLifetimeSeconds) {
            return (Get-Content $TokenCacheFile | ConvertFrom-Json).access_token
        }
    }

    Write-Host "❌ Access token is missing or expired. Please wait for the hourly renewal task or contact IT support."
    exit 1
}

# -------------------------------
# MAIN LOGIC
# -------------------------------
echo ""
Write-Host "📱 Device Details"
Write-Host "Choose search type:"
Write-Host "1. Serial Number"
Write-Host "2. User ID"
$searchOption = Read-Host "Enter option [1-2]"

switch ($searchOption) {
    "1" {
        $apiMode = "serial"
        $input = Read-Host "Enter one or more 10- or 12-character serial numbers (comma-separated)"
        $identifiers = $input -split ',' | ForEach-Object { $_.Trim() }
        foreach ($id in $identifiers) {
            if ($id.Length -ne 10 -and $id.Length -ne 12) {
                Write-Host "❌ Invalid serial number: $id"
                exit 1
            }
        }
    }
    "2" {
        $apiMode = "user"
        $input = Read-Host "Enter one or more User IDs (comma-separated)"
        $identifiers = $input -split ',' | ForEach-Object { $_.Trim() }
    }
    default {
        Write-Host "❌ Invalid option selected."
        exit 1
    }
}

Write-Host "`n📜 You entered:"
$identifiers | ForEach-Object { Write-Host "- $_" }

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$safeIds = $identifiers | ForEach-Object { $_ -replace '[^\w]', '_' }
$outputFile = if ($safeIds.Count -gt 3) {
    "$HOME\Downloads\device_details_$($safeIds[0..1] -join "_")_count$($safeIds.Count)_$timestamp.txt"
} else {
    "$HOME\Downloads\device_details_$($safeIds -join "_")_$timestamp.txt"
}

Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
$accessToken = Get-WS1Token

$shouldQuery = Read-Host "Would you like to query the devices for updated information? (y/n)"

foreach ($id in $identifiers) {
    try {
        $deviceSearchUrl = if ($apiMode -eq "serial") {
            "$ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$id"
        } else {
            "$ws1EnvUrl/mdm/devices/search?user=$id"
        }

        $searchResponse = Invoke-RestMethod -Uri $deviceSearchUrl -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" }
        $devices = if ($apiMode -eq "serial") { @($searchResponse) } else { $searchResponse.Devices }

        if (-not $devices -or $devices.Count -eq 0) {
            $msg = "❌ No device found for identifier: $id`n"
            Write-Host $msg.Trim() -ForegroundColor Yellow
            $msg | Out-File -FilePath $outputFile -Append
            continue
        }

        foreach ($device in $devices) {
            $deviceDetail = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices/$($device.Id.Value)" -Headers @{ Authorization = "Bearer $accessToken"; Accept = "application/json" }

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
            $details | Tee-Object -Append -FilePath $outputFile

            # Smart Groups
            $sgResponse = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices/$($deviceDetail.Id.Value)/smartgroups" -Headers @{
                Authorization = "Bearer $accessToken"
                Accept        = "application/json;version=1"
            }
            "📂 Smart Groups" | Tee-Object -FilePath $outputFile -Append
            "-----------------------------" | Tee-Object -FilePath $outputFile -Append
            $sgResponse.SmartGroup | ForEach-Object {
                "ID: $($_.SmartGroupId.Value) - Name: $($_.SmartGroupName)"
            } | Tee-Object -FilePath $outputFile -Append
            "" | Out-File -FilePath $outputFile -Append

            # Tags
            $uuid = $deviceDetail.Id.Uuid
            if (-not $uuid -or $uuid -eq "") {
                $uuid = $deviceDetail.Uuid
            }
            if (-not $uuid -or $uuid -eq "") {
                throw "❌ UUID not found for Device ID $($deviceDetail.Id.Value)"
            }

            $tagResponse = Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices/$uuid/tags" -Headers @{
                Authorization = "Bearer $accessToken"
                Accept        = "application/json;version=1"
            }
            "🏷️ Tags" | Tee-Object -FilePath $outputFile -Append
            "-----------------------------" | Tee-Object -FilePath $outputFile -Append
            if ($tagResponse.tags.Count -gt 0) {
                $tagResponse.tags | ForEach-Object {
                    "Name: $($_.name) - Tagged On: $($_.date_tagged)"
                } | Tee-Object -FilePath $outputFile -Append
            } else {
                "No tags assigned." | Tee-Object -FilePath $outputFile -Append
            }
            "" | Out-File -FilePath $outputFile -Append

            # Optional Sync
            if ($shouldQuery -match '^(y|Y)') {
                $platform = $deviceDetail.Platform
                $commandType = if ($platform -eq "Apple") { "DeviceInformation" } elseif ($platform -eq "Android") { "DeviceQuery" } else { $null }

                if ($commandType) {
                    Write-Host "🛁 Requesting updated device information for: $($deviceDetail.SerialNumber)"
                    Invoke-RestMethod -Uri "$ws1EnvUrl/mdm/devices/$($deviceDetail.Id.Value)/commands?command=$commandType" -Method Post -Headers @{
                        Authorization = "Bearer $accessToken"
                        Accept        = "application/json"
                        'Content-Type' = "application/json"
                        'Content-Length' = 0
                    }
                    Write-Host "✅ Device information has been successfully requested.`n"
                } else {
                    Write-Host "⚠️ Platform not supported for command: $($platform)"
                }
            }
        }
    } catch {
        $msg = "⚠️ Failed to process identifier: $id - $($_.Exception.Message)"
        Write-Host $msg -ForegroundColor Yellow
        $msg | Out-File -FilePath $outputFile -Append
        "" | Out-File -FilePath $outputFile -Append
    }
}

Write-Host "`n🗘️ Results saved to $outputFile"
