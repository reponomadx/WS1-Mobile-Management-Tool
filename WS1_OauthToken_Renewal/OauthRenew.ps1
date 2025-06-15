# --------------------------------
# SCRIPT PURPOSE
# --------------------------------
# This script retrieves an OAuth 2.0 access token from the Workspace ONE UEM API
# using client credentials and caches it to a shared JSON file. The token is only
# refreshed if the existing one is older than 55 minutes (3300 seconds).
#
# Intended for use with scheduled tasks to ensure consistent and secure token
# availability across systems.

# --------------------------------
# CONFIGURATION
# --------------------------------
$tokenCacheFile = "\\Path\To\WS1_OauthToken_Renewal\ws1_token_cache.json"
$tokenLifetimeSeconds = 3300
$tokenUrl = "https://na.uemauth.workspaceone.com/connect/token"
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"

# --------------------------------
# TOKEN FUNCTION
# --------------------------------
function Get-WS1Token {
    # Check if the token cache file exists and is still valid (under 55 minutes old)
    if (Test-Path $tokenCacheFile) {
        $age = (Get-Date) - (Get-Item $tokenCacheFile).LastWriteTime
        if ($age.TotalSeconds -lt $tokenLifetimeSeconds) {
            Write-Host "✅ Existing token is still valid."
            return
        }
    }

    # Token is missing or expired — request a new one from Workspace ONE
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
    }

    # Save the new token JSON to the shared cache file
    $response | ConvertTo-Json -Depth 10 | Out-File $tokenCacheFile
    Write-Host "✅ New token saved to cache."
}

# --------------------------------
# EXECUTION
# --------------------------------
Get-WS1Token