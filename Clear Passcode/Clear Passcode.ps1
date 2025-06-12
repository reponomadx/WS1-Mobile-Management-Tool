# -----------------------------------------------------------------------------
# Script Name: ClearPasscode.ps1
# Purpose: Send Clear Passcode command to one or more devices by serial number
# Description:
#   This script authenticates to Workspace ONE via OAuth, prompts for one or more
#   serial numbers, and sends the Clear Passcode command to each device.
#   It handles basic error output and logs responses for visibility.
# -----------------------------------------------------------------------------

# --------------------------------
# CONFIGURATION
# --------------------------------

# Directory where OAuth token is cached
$OAuthDir = "\\HOST_SERVER\MobileManagementTool\Oauth Token"
$TokenCacheFile = "$OAuthDir\ws1_token_cache.json"
$TokenLifetimeSeconds = 3600  # 1 hour

# Workspace ONE API configuration (replace with real values during deployment)
$Ws1EnvUrl    = "https://YOUR_OMNISSA_ENV.awmdm.com/API"
$TokenUrl     = "https://na.uemauth.workspaceone.com/connect/token"
$ClientId     = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"
$TenantCode   = "YOUR_TENANT_CODE"

# --------------------------------
# FUNCTIONS
# --------------------------------

# Retrieves a cached token if still valid, otherwise requests a new one
function Get-WS1Token {
    $now = Get-Date
    if (Test-Path $TokenCacheFile) {
        $fileAge = (Get-Date) - (Get-Item $TokenCacheFile).LastWriteTime
        if ($fileAge.TotalSeconds -lt $TokenLifetimeSeconds) {
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

# --------------------------------
# MAIN LOGIC
# --------------------------------

# Get token
$AccessToken = Get-WS1Token

echo ""
Write-Host "Clear Passcode"

# Prompt for comma-separated serial numbers
$serialInput = Read-Host "Enter one or more device serial numbers (comma-separated)"
$serials = $serialInput -split "," | ForEach-Object { $_.Trim() }

# Iterate over each device serial
foreach ($serial in $serials) {
    Write-Host "🔓 Clearing passcode for device with serial: $serial..."

    # Construct request body (sample/test values below — replace if needed)
    $jsonBody = @{
        deviceWipe = @{
            disableActivationKey   = $true
            disallowProximitySetup = $true
            preserveDataPlan       = $true
            wipeType               = "WIPE"
        }
        workPasscode      = $true
        AllowPinAtStartup = $true
        esim_url          = "https://esim.placeholder.com"
        unlock_pin        = 123789
        message           = "Sample unlock message"
        managed_apple_id  = "noreply@example.com"
        sensor_names      = @("Text value")
        reboot_count      = 3
        device_restart    = @{
            rebuild_kernel_cache = $true
            kext_paths           = @("Text value")
        }
    } | ConvertTo-Json -Depth 5

    # Make API call
    try {
        $response = Invoke-RestMethod -Method Post -Uri "$Ws1EnvUrl/mdm/devices/commands/ClearPasscode/device/SerialNumber/$serial" `
            -Headers @{
                "accept"         = "application/json;version=2"
                "Authorization"  = "Bearer $AccessToken"
                "aw-tenant-code" = $TenantCode
                "Content-Type"   = "application/json"
            } -Body $jsonBody

        if ($response.errorCode -eq $null -or $response.errorCode -eq 0) {
            Write-Host "✅ Passcode cleared successfully for device $serial"
        }
        else {
            Write-Host "❌ Failed to clear passcode for device $serial"
            Write-Host "Error Code : $($response.errorCode)"
            Write-Host "Message    : $($response.message)"
        }
    }
    catch {
        Write-Host "⚠️  Response is not valid JSON or request failed:"
        Write-Host $_.Exception.Message
    }

    Write-Host ""
}
