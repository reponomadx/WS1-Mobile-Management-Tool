<#
.SYNOPSIS
Main entry point for the Workspace ONE Mobile Management Tool.

.DESCRIPTION
This menu script provides IT administrators with a centralized interface 
for managing Workspace ONE devices. It handles token validation, session 
logging, device counts, and script execution. Includes inactivity timeout 
and device count telemetry.

.VERSION
v1.3.0
#>

# --------------------------------
# HOSTNAME VALIDATION
# --------------------------------
$validHosts = @('HOSTNAME_1', 'HOSTNAME_2', 'HOSTNAME_3', 'HOSTNAME_4', 'HOSTNAME_5', 'HOSTNAME_6', 'HOSTNAME_7')
$currentHost = $env:COMPUTERNAME

Start-Sleep -Seconds 2

if ($validHosts -notcontains $currentHost) {
    Write-Host "❌ This script can only be run on authorized IT hosts." -ForegroundColor Red
    Stop-Process -Id $PID
}

# -------------------------------
# CONFIGURATION
# -------------------------------
$ws1EnvUrl = "https://YOUR_OMNISSA_ENV.awmdm.com"
$TokenPath = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$uuid = "YOUR_ORG_GROUP_UUID"

# -------------------------------
# Get OAuth Token from Cache
# -------------------------------
function Get-WS1Token {
    $tokenData = Get-Content $TokenPath | ConvertFrom-Json
    return $tokenData.access_token
}

# -------------------------------
# Get Enrolled Device Count
# -------------------------------
function Get-EnrolledDeviceCount {
    param (
        [string]$uuid = $null
    )

    $token = Get-WS1Token
    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept"        = "*/*"
        "Content-Type"  = "application/json"
    }

    $url = "$ws1EnvUrl/api/mdm/devices/enrolleddevicescount"

    $body = if ($uuid) {
        @{ uuid = $uuid } | ConvertTo-Json -Compress
    } else {
        '{}'  # Empty JSON object
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body
        return $response
    } catch {
        Write-Error "❌ Failed to get enrolled device count: $_"
    }
}

# -------------------------------
# Token Status
# -------------------------------
function Get-TokenStatus {
    param (
        [string]$TokenPath,
        [int]$MaxAgeMinutes = 60
    )

    if (!(Test-Path $TokenPath)) {
        return "❌ Offline"
    }

    $tokenAge = ((Get-Date) - (Get-Item $TokenPath).LastWriteTime).TotalMinutes
    if ($tokenAge -lt $MaxAgeMinutes) {
        return "✅ Online"
    } else {
        return "❌ Offline"
    }
}

# -------------------------------
# Show Menu
# -------------------------------
function Show-Menu {
    Clear-Host
    Write-Host "!!! Authorized Use Only !!!" -ForegroundColor Yellow
    Write-Host "This tool is for internal IT use only. Unauthorized use or modification is prohibited." -ForegroundColor Green
    Write-Host "PROD Logged in as: $env:USERNAME on $env:COMPUTERNAME" -ForegroundColor Gray
    echo ""
    Write-Host " Devices: $($response.DevicesCount)            Status: $tokenStatus" -ForegroundColor Gray
    Write-Host " --------------------------------------------" 
    Write-Host "|  Workspace ONE Mobile Management Tool      |" -ForegroundColor Cyan
    Write-Host " --------------------------------------------" 
    Write-Host "|  1) Restart device(s)                      |"
    Write-Host "|  2) Device(s) Details/Information          |"
    Write-Host "|  3) Add/Remove Tag                         |"
    Write-Host "|  4) ADE (DEP) Assign/Unassign              |"
    Write-Host "|  5) Clear Passcode                         |"
    Write-Host "|  6) Device Wipe                            |"
    Write-Host "|  7) Apps Query                             |"
    Write-Host "|  8) App Install                            |"
    Write-Host "|  9) Profiles Assigned                      |"
    Write-Host "| 10) Device Event Log (1000 Entries)        |"
    Write-Host "| 11) Delete Device(s)                       |"
    Write-Host "| 12) Enable/Disable Lost Mode               |"
    Write-Host "| 13) Update iOS/iPadOS                      |"
    Write-Host "|  0) Exit                                   |" -ForegroundColor Red
    Write-Host " --------------------------------------------"
}

function Run-Script($path) {
    if (Test-Path $path) {
        & $path
    } else {
        Write-Host "`n❌ Script not found: $path" -ForegroundColor Red
    }
}

# --------------------------------
# SESSION LOG SETUP
# --------------------------------
$logFolder = "\\HOST_SERVER\MobileManagementTool\UserLogs"
$sessionTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionUser = $env:USERNAME
$sessionLogPath = "$logFolder\PROD_Session_${sessionUser}_$sessionTimestamp.log"

# Cleanup old session logs (older than 90 days)
Get-ChildItem -Path $logFolder -Filter "Session_*.log" | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-90)
} | Remove-Item -Force

function Log-Action($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp | User: $env:USERNAME | Host: $env:COMPUTERNAME | Action: $message"
    Add-Content -Path $sessionLogPath -Value $entry
}

# Log session start
Log-Action "Session started"

# --------------------------------
# Get Input With Timeout
# --------------------------------
function Get-UserInputWithTimeout {
    param (
        [int]$timeoutSeconds = 120
    )
    $startTime = Get-Date
    $inputBuffer = ""

    Write-Host "`nSelect an option [0-13] (timeout in $timeoutSeconds sec):" -NoNewline

    while (((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'Enter' {
                    Write-Host
                    return $inputBuffer.Trim()
                }
                'Backspace' {
                    if ($inputBuffer.Length -gt 0) {
                        $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                        [Console]::Write("`b `b")
                    }
                }
                default {
                    if ($key.KeyChar -match '\d') {
                        $inputBuffer += $key.KeyChar
                        Write-Host -NoNewline $key.KeyChar
                    }
                }
            }
        }
        Start-Sleep -Milliseconds 200
    }

    Write-Host "`n⏳ Session timed out due to inactivity. Exiting..." -ForegroundColor Yellow
    Log-Action "Session timeout - script exited"
    exit
}

# --------------------------------
# MAIN LOOP
# --------------------------------
while ($true) {
    $response = Get-EnrolledDeviceCount
    if (-not $response) { $response = @{ DevicesCount = "N/A" } }

    $tokenStatus = Get-TokenStatus -TokenPath $TokenPath

    Show-Menu

    $choice = Get-UserInputWithTimeout

    if ($null -eq $choice -or $choice -notmatch '^\d+$' -or [int]$choice -lt 0 -or [int]$choice -gt 13) {
        Write-Host "`n❌ Invalid input. Please enter a number between 0 and 13." -ForegroundColor Red
        Start-Sleep -Seconds 2
        continue
    }

    if ($choice -eq '0') {
        Log-Action "Exited menu"
        Write-Host "`n👋 Exiting menu..." -ForegroundColor Yellow
        break
    }

    switch ($choice) {
        '1'  { Log-Action "Restart device(s)"; Run-Script "\\HOST_SERVER\MobileManagementTool\Restart Device\Restart Device.ps1" }
        '2'  { Log-Action "Device(s) Details/Information"; Run-Script "\\HOST_SERVER\MobileManagementTool\Device Details\Device Details.ps1" }
        '3'  { Log-Action "Add/Remove Tag"; Run-Script "\\HOST_SERVER\MobileManagementTool\AddRemove Tag\AddRemove Tag.ps1" }
        '4'  { Log-Action "ADE (DEP) Assign/Unassign"; Run-Script "\\HOST_SERVER\MobileManagementTool\DEP\Assign or Unassign DEP.ps1" }
        '5'  { Log-Action "Clear Passcode"; Run-Script "\\HOST_SERVER\MobileManagementTool\Clear Passcode\Clear Passcode.ps1" }
        '6'  { Log-Action "Device Wipe"; Run-Script "\\HOST_SERVER\MobileManagementTool\Device Wipe\Device Wipe.ps1" }
        '7'  { Log-Action "Apps Query"; Run-Script "\\HOST_SERVER\MobileManagementTool\Apps\Apps.ps1" }
        '8'  { Log-Action "App Install"; Run-Script "\\HOST_SERVER\MobileManagementTool\Apps\Install App.ps1" }
        '9'  { Log-Action "Profiles Assigned"; Run-Script "\\HOST_SERVER\MobileManagementTool\Profiles\Profiles.ps1" }
        '10' { Log-Action "Device Event Log (1000 Entries)"; Run-Script "\\HOST_SERVER\MobileManagementTool\Device Event Log\Device Event Log.ps1" }
        '11' { Log-Action "Delete Device(s)"; Run-Script "\\HOST_SERVER\MobileManagementTool\Delete\Delete.ps1" }
        '12' { Log-Action "Enable/Disable Lost Mode"; Run-Script "\\HOST_SERVER\MobileManagementTool\Lost Mode\LostMode.ps1" }
        '13' { Log-Action "Update iOS/iPadOS"; Run-Script "\\HOST_SERVER\MobileManagementTool\Update iOS\Update iOS.ps1" }
    }

    Write-Host "`nPress Enter to return to the main menu..."
    [void][System.Console]::ReadLine()
}
