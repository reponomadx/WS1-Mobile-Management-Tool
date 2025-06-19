# 📋 Changelog

All notable updates to the WS1 Mobile Management Tool are documented below.

---

## [v1.2.2] - 2025-06-18
### 🛠 Fixes
- Fixed version output in `Apps.ps1` — now pulls from `installed_version` field correctly
- Fixed install failure messaging in `Install App.ps1` — now consistently shows "❌ [AppName] is not assigned to the device."

### ✏️ Improvements
- Updated all script headers to reflect their actual filenames for improved clarity and maintainability

---

## [v1.2.1] - 2025-06-18
### ✅ Changes
- Refactored `Assign or Unassign DEP.ps1` to support centralized OAuth token caching
- Removed embedded Client ID and Secret from the script
- Updated token retrieval logic for reliability and fallback safety
- Replaced hardcoded unassign UUID with a placeholder
- Improved logging structure and messaging for profile assign/unassign actions

---

## [v1.2.0] - 2025-06-15  
### 🔐 Security & OAuth Overhaul
- Removed Client ID and Secret from all scripts
- All scripts now pull token from a **shared cached file**
- Scripts no longer require local write access to generate tokens
- Introduced **hourly OAuth token refresh via Task Scheduler**

### ✅ Updated Scripts
Refactored for centralized token usage:
- `AddRemove Tag.ps1`
- `Apps.ps1`
- `Install App.ps1`
- `Clear Passcode.ps1`
- `Delete.ps1`
- `Device Details.ps1`
- `Device Event Log.ps1`
- `Device Wipe.ps1`
- `LostMode.ps1`
- `Profiles.ps1`
- `Restart Device.ps1`

### 🛠 Improvements
- Token caching fallback logic added
- Scripts now fail gracefully if no token is found
- Preserved CSV and log behavior from previous versions
- Fully backwards-compatible with WS1 API v1+v2

---

## [v1.1.0] - 2025-06-15
### 🚀 OAuth Token Auto-Renewal Support
- Added `WS1 OAuth Token.xml` Task Scheduler config (runs hourly)
- Added `OauthRenew.ps1` and wrapper batch file for token renewal
- Optional sample log output (`refresh.log`) included

### ✅ How It Works
- A fresh token is always present
- Designed to work unattended with no user input

---

## [v1.0.1] - 2025-06-11
### 🛠 Token URL & Terminology Update
- Updated token URL to new Omnissa endpoint:  
  `https://na.uemauth.workspaceone.com/connect/token`
- Replaced all user-facing references of "DEP" with **ADE (Automated Device Enrollment)** to align with Apple terminology

---

## [v1.0.0] - 2025-06-09
### 🎉 Initial Release – Workspace ONE Admin Toolkit
A suite of PowerShell scripts to automate admin workflows in Omnissa (Workspace ONE) environments.

### 🚀 Included Scripts
- `Device Details.ps1` – Lookup device info, Smart Groups, tags
- `Device Wipe.ps1` – Secure wipe with logging
- `Device Event Log.ps1` – Fetch latest 1,000 event logs
- `LostMode.ps1` – Enable/disable Lost Mode with message
- `Restart Device.ps1` – Soft reboot by serial (bulk capable)
- `Assign or Unassign DEP.ps1` – Assign/unassign DEP profiles (Basic Auth)
- `Profiles.ps1` – Export installed profiles as CSV
- `AddRemove Tag.ps1` - Add or Remove tags
- and more...

### 🔒 Authentication
- OAuth token caching with fallback
- Secure credential placeholders
- Configurable environment structure

### 📁 Output & Logging
- All scripts write to local `Downloads` folder or a share path
- Designed for clean audit trails and human-readable output

---
