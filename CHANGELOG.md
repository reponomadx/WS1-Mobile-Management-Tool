# 📋 Changelog

All notable updates to the WS1 Mobile Management Tool are documented below.

---

## [v1.3.0] - 2025-06-20
### 🎉 Major Feature Release
This is the largest and most refined version to date, focused on code quality, documentation, and centralized security.

### 🔐 Security & Structure
- All scripts now use centralized **OAuth token caching**
- Removed all environment-specific paths, tenant codes, and credentials

### 🖊️ Comments & Headers
- Added standardized headers to every script:
  - `.SYNOPSIS`, `.DESCRIPTION`, `.VERSION`
- Inline comments explain function purpose, input logic, API interaction
- Cyan-colored script titles added for improved readability

### ❌ Removed
- Deprecated Basic Auth logic
- Eliminated any need for write access by general users

### ✅ New or Updated Scripts
- `Apps.ps1` – List apps assigned to device
- `Install Purchased App.ps1` – Deploy VPP apps
- `Clear Passcode.ps1` – Clears passcode on locked iOS device
- `Update iOS.ps1` – Triggers OS update on compatible iOS devices

### 📆 Graceful Execution
- All scripts now check for required input and exit cleanly if not provided
- No more unhandled prompts or crashes on empty input

### 🔧 General Improvements
- Unified script formatting, spacing, indentation, and output style
- CSVs, logs, and error handling consistent across all tools
- Better compatibility with future script expansion

---

## [v1.2.3] - 2025-06-18
### 🧹 Final Patch for v1.2.x Series
Finalized v1.2.x with sanitization, alignment, and polish.

### 🛠 Fixes
- Sanitized `menu.ps1` for public release
- Removed all internal identifiers
- Fixed script label alignment in CLI menu

### ✏️ Improvements
- README updated with version badges
- Clarified documentation sections and output paths

---

## [v1.2.2] - 2025-06-18
### 🛠 Fixes
- `Apps.ps1` correctly pulls `installed_version`
- Improved app install error messaging

### ✏️ Improvements
- All script headers renamed to match filenames

---

## [v1.2.1] - 2025-06-18
### ✅ Changes
- OAuth cache support added to DEP assignment
- Client credentials removed from codebase
- Added logging for profile actions

---

## [v1.2.0] - 2025-06-15
### 🔐 Security & OAuth Overhaul
- Centralized token cache
- Removed embedded secrets
- Scheduled task support introduced

### ✅ Updated Scripts
- Major refactor across all active scripts

### 🛠 Improvements
- Graceful token fallback logic
- Output preservation and compatibility

---

## [v1.1.0] - 2025-06-15
### 🚀 OAuth Auto-Renewal Support
- Token refresh runs hourly via Task Scheduler

---

## [v1.0.1] - 2025-06-11
### 🛠 Token URL & Terminology Update
- Updated to `na.uemauth.workspaceone.com`
- "DEP" renamed to ADE in UI

---

## [v1.0.0] - 2025-06-09
### 🎉 Initial Release
PowerShell-based admin toolkit for Workspace ONE UEM

### 🔒 Auth
- OAuth token logic
- Basic Auth support

### 📂 Output
- Audit-friendly CSVs and logs
