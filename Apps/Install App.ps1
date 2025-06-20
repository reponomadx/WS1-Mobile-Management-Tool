<#
.SYNOPSIS
Pushes an assigned purchased app to a device in Workspace ONE.

.DESCRIPTION
This script uses a shared OAuth token to retrieve all purchased apps and 
allows the user to push a selected app to one or more devices by serial number. 
It is intended for bulk or individual VPP app deployments.

.VERSION
v1.3.0
#>

# --------------------------------
# CONFIGURATION
# --------------------------------
$TokenCacheFile = "\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json"
$Ws1EnvUrl      = "https://YOUR_OMNISSA_ENV.awmdm.com"
$OrgGroupUUID   = "YOUR_ORG_GROUP_UUID"
$TenantCode     = "YOUR_TENANT_CODE"

# -------------------------------
# Get OAuth Token from Cache
# -------------------------------
function Get-WS1Token {
    if (-Not (Test-Path $TokenCacheFile)) {
        Write-Host "❌ Token cache not found at $TokenCacheFile" -ForegroundColor Red
        exit 1
    }

    try {
        $tokenData = Get-Content $TokenCacheFile | ConvertFrom-Json
        return $tokenData.access_token
    }
    catch {
        Write-Host "❌ Failed to parse token cache." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# --------------------------------
# MAIN
# --------------------------------
$accessToken = Get-Ws1Token
Write-Host "`n📦 Retrieving all purchased apps..."
$outputCsv = "$HOME\Downloads\All_Purchased.csv"

$purchasedApps = Invoke-RestMethod -Method Get -Uri "$Ws1EnvUrl/api/mam/apps/purchased/search?organizationgroupuuid=$OrgGroupUUID" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept        = "application/json;version=1"
}

if (-not $purchasedApps.Application) {
    Write-Host "❌ No purchased apps returned by API."
    exit 1
}

$purchasedApps.Application | Select-Object ApplicationName, BundleId, Platform, Id |
    Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "✅ Saved app list to $outputCsv`n"

$serialInput = Read-Host "Enter one or more serial numbers (comma-separated)"
$serials = $serialInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

$appId = Read-Host "Enter App ID to install (from CSV)"
foreach ($serial in $serials) {
    Write-Host "`n🔍 Looking up Device ID for serial: $serial..."
    $deviceData = Invoke-RestMethod -Uri "$Ws1EnvUrl/api/mdm/devices?searchby=Serialnumber&id=$serial" -Headers @{
        Authorization   = "Bearer $accessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    $deviceId = $deviceData.Id.Value
    if (-not $deviceId) {
        Write-Host "❌ Could not find device for serial: $serial"
        continue
    }

    Write-Host "📲 Installing app on $serial..."
    $response = Invoke-RestMethod -Uri "$Ws1EnvUrl/api/mam/apps/purchased/$appId/devices/$deviceId/install" -Method Post -Headers @{
        Authorization   = "Bearer $accessToken"
        Accept          = "application/json"
        "aw-tenant-code"= $TenantCode
    }

    if ($response.message -eq $null) {
        Write-Host "✅ App install command sent for $serial"
    } else {
        Write-Host "❌ Failed to install on $serial"
        Write-Host "📄 Error: $($response.message)"
    }
}
