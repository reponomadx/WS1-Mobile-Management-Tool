# -----------------------------------------------------------------------------
# Script Name: Device Wipe.ps1
# Purpose: Issue wipe or enterprise wipe commands for Workspace ONE devices
# Description:
#   This script allows IT administrators to securely issue device wipe commands
#   against devices managed by Workspace ONE. It supports both full device wipes
#   for corporate-owned devices and enterprise wipes for employee-owned devices.
#   All actions are confirmed with the admin, and results are logged to the
#   user's Downloads folder.
# -----------------------------------------------------------------------------

# -------------------------------
# CONFIGURATION
# -------------------------------

# Path to OAuth token cache directory and file
$OAuthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600  # Token validity duration (in seconds)

# Workspace ONE API endpoint and credentials (placeholders)
$Ws1EnvUrl    = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$TokenUrl     = "https://na.uemauth.workspaceone.com/connect/token"
$ClientId     = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"
$TenantCode   = "YOUR_TENANT_CODE"

# Define where to log the wiped device serials
$LogFilePath = [System.IO.Path]::Combine($HOME, "Downloads", "WipedDevices.txt")
New-Item -Path (Split-Path $LogFilePath) -ItemType Directory -Force | Out-Null
"" | Out-File -FilePath $LogFilePath  # Clear or create the log file

# -------------------------------
# FUNCTIONS
# -------------------------------

# Function: Retrieves a cached OAuth token if valid, or requests a new one
function Get-WS1Token {
    if (Test-Path $TokenCacheFile) {
        $tokenAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($tokenAge.TotalSeconds -lt $TokenLifetimeSeconds) {
            $cachedToken = Get-Content $TokenCacheFile | ConvertFrom-Json
            return $cachedToken.access_token
        }
    }

    Write-Host "🔐 Requesting new Workspace ONE access token..."
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
    }
    $response = Invoke-RestMethod -Method Post -Uri $TokenUrl -Body $body -ContentType "application/x-www-form-urlencoded"

    if (-not $response.access_token) {
        Write-Host "❌ Failed to obtain access token. Exiting."
        exit 1
    }

    $response | ConvertTo-Json | Set-Content -Path $TokenCacheFile
    return $response.access_token
}

# Function: Prompts the admin to confirm an action with (y/n)
function Confirm-Prompt($message) {
    $confirmation = Read-Host "$message (y/n)"
    return $confirmation -eq "y" -or $confirmation -eq "Y"
}

# -------------------------------
# MAIN LOGIC
# -------------------------------

# Get valid token to use for API requests
$AccessToken = Get-WS1Token

# Prompt for serial numbers to wipe (comma-separated)
Write-Host "`nDevice Wipe"
$serialInput = Read-Host "Enter one or more device serial numbers (comma-separated)"
Write-Host ""

# Split input into an array of trimmed serials
$serials = $serialInput -split "," | ForEach-Object { $_.Trim() }

# Check for unsupported placeholder serial used by Android
foreach ($serial in $serials) {
    if ($serial -ieq "HUBNOSERIAL") {
        Write-Host "🚫 The serial number '$serial' is a placeholder used by Android devices." -ForegroundColor Yellow
        Write-Host "❌ Device wipe is not supported for Android devices at this time." -ForegroundColor Red
        exit 1
    }
}

# Final confirmation prompt
Write-Host "⚠️  WARNING: You are about to issue a wipe command. Please verify the serial number(s): $serialInput"
Write-Host ""
if (-not (Confirm-Prompt "❓ Do you want to proceed?")) {
    Write-Host "`n❌ Operation cancelled."
    exit 1
}

# Loop through each serial to query ownership and issue wipe
foreach ($serial in $serials) {
    Write-Host "`n🔍 Checking device ownership for serial: $serial"

    $deviceDetailsUrl = "$Ws1EnvUrl/mdm/devices?searchby=Serialnumber&id=$serial"
    try {
        $deviceDetails = Invoke-RestMethod -Method Get -Uri $deviceDetailsUrl -Headers @{
            "accept"         = "application/json;version=1"
            "Authorization"  = "Bearer $AccessToken"
            "aw-tenant-code" = $TenantCode
        }

        $ownership = $deviceDetails.Ownership
        if (-not $ownership) {
            Write-Host "🚫 No device found or missing Ownership for serial: $serial"
            continue
        }

        # Handle employee-owned (Enterprise Wipe)
        if ($ownership -eq "E") {
            if (-not (Confirm-Prompt "❓ Proceed with an Enterprise Wipe on employee-owned device $serial?")) {
                Write-Host "⛔ Skipping device $serial"
                continue
            }

            Write-Host "📡 Issuing enterprise wipe for device $serial..."
            $body = @{ BulkValues = @{ Value = @($serial) } } | ConvertTo-Json -Depth 3
            $response = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/mdm/devices/commands/bulk?command=EnterpriseWipe&searchby=Serialnumber" `
                -Headers @{
                    "accept"         = "application/json;version=1"
                    "Authorization"  = "Bearer $AccessToken"
                    "aw-tenant-code" = $TenantCode
                    "Content-Type"   = "application/json"
                } -Body $body

            if ($response.AcceptedItems -eq 1 -and $response.FailedItems -eq 0) {
                Write-Host "✅ Enterprise wipe command accepted for device $serial"
                "$serial" | Out-File -FilePath $LogFilePath -Append
            } else {
                Write-Host "❌ Enterprise wipe request failed for device $serial"
                $response | ConvertTo-Json -Depth 3
            }
        }
        # Handle corporate-owned (Full Wipe)
        else {
            if (-not (Confirm-Prompt "❓ Proceed with a full device wipe on corporate-owned device $serial?")) {
                Write-Host "⛔ Skipping device $serial"
                continue
            }

            Write-Host "💥 Wiping corporate-owned device with serial: $serial..."
            $body = @{
                disableActivationLock = $true
                wipeInternalStorage   = $true
                wipeSDCard            = $true
                protectWipe           = $false
            } | ConvertTo-Json -Depth 3

            $response = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/mdm/devices/commands/DeviceWipe/device/SerialNumber/$serial" `
                -Headers @{
                    "accept"         = "application/json;version=2"
                    "Authorization"  = "Bearer $AccessToken"
                    "aw-tenant-code" = $TenantCode
                    "Content-Type"   = "application/json"
                } -Body $body

            if ($response.errorCode -eq $null -or $response.errorCode -eq 0) {
                Write-Host "✅ Wipe command issued successfully for device $serial"
                "$serial" | Out-File -FilePath $LogFilePath -Append
            } else {
                Write-Host "❌ Failed to wipe device $serial"
                Write-Host "Error Code : $($response.errorCode)"
                Write-Host "Message    : $($response.message)"
            }
        }
    } catch {
        Write-Host "❌ Error processing device $serial"
        Write-Host $_.Exception.Message
    }
    Write-Host ""
}

# Final output
Write-Host "`n📄 Wiped device serials logged to: $LogFilePath"
