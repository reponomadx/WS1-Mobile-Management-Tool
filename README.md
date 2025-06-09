# WS1 Mobile Management Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-lightgrey)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![WorkspaceONE](https://img.shields.io/badge/WorkspaceONE-API_Integrated-blueviolet.svg)](https://developer.vmware.com/apis/ws1/)
[![GroundControl](https://img.shields.io/badge/GroundControl-Compatible-yellow.svg)](https://www.imprivata.com/groundcontrol)

The **WS1 Mobile Management Tool** is a PowerShell-based suite designed to streamline and automate common device management tasks within VMware Workspace ONE UEM environments. Originally developed in a healthcare enterprise setting, this tool enables administrators to perform high-frequency, high-impact operations from a centralized, interactive CLI interface—bypassing the need to navigate the Workspace ONE web console.

---

## ✨ Overview
Built with modularity in mind, this toolkit leverages the Workspace ONE REST API to deliver direct, reliable device interaction, including device lookups, tag modifications, DEP assignments, app queries, profile audits, and more.

Whether managing 10 or 10,000 devices, this menu-driven utility accelerates administrative workflows by:
- Reducing time-to-action
- Abstracting API complexity
- Logging each touchpoint

---

## ✅ Core Features

- 🔁 Restart devices across assignment groups
- 🔍 Lookup and display rich device metadata
- 📦 Query installed and assigned apps
- 🧩 View assigned configuration profiles
- 🏷️ Add or remove Workspace ONE tags
- 🚚 Assign/unassign DEP profiles
- 🔐 Clear device passcodes (gracefully handled)
- 💣 Perform enterprise or full device wipes
- 📑 Retrieve the 1,000 most recent device event log entries
- 👥 Retrieve Smart Group and Tag memberships
- 👤 Search by Username (User ID) or Serial Number
- ⏲️ Auto-exit on 5-minute inactivity
- 💬 Modular scripting with reusable API logic blocks

---

## 🗂 Folder Structure (Technical Layout)

```
WS1_Mobile_Management_Tool/
├── AddRemove Tag/              # Scripts for GET/POST tag association API endpoints
├── Apps/                      # App assignment retrieval, install pushes
├── Clear Passcode/            # POST to passcode clear endpoint with status check
├── Delete/                    # DELETE and validation against enrollment status
├── DEP/                       # PUT/DELETE to DEP profile assignment endpoints
├── Device Details/            # Pull device info using deviceId lookup, enriched with assigned SmartGroups and tags
├── Device Event Log/          # Retrieve logs via /devices/events endpoint (limit 1000)
├── Device Wipe/               # POST to enterprise/factory wipe endpoints with optional retention
├── Lost Mode/                 # Toggle lost mode (enable/disable) and retrieve status
├── menu/                      # Central launcher logic and dispatcher
├── Oauth Token/               # Oauth Token Cache
├── Profiles/                  # Assigned profile queries via /devices/profiles API
├── Restart Device/            # Soft reboot trigger via Workspace ONE API
├── UserLogs/                  # Optional: user search input history, action audit
├── PREPROD_WS1-Mobile-Management-Tool.bat 	#Menu Launch # Primary launcher for the pre-production version of the PowerShell tool
├── WS1-Mobile-Management-Tool.bat	# Primary launcher for the production version of the PowerShell tool
├── PREPROD_ChangeLog.log
├── PROD_ChangeLog.log
```

---

## ⚙️ Prerequisites
- Windows 10/11 or Windows Server (console role)
- PowerShell 5.1+ (Windows PowerShell, not Core)
- Access to Workspace ONE UEM API
- OAuth2 credentials with at least:
  - `DeviceManagement` and `UserManagement` scopes
- Internet access to WS1 API endpoints

---

## 🚀 Getting Started

Launch the tool using either of the `.bat` entry points:
```bat
WS1-Mobile-Management-Tool.bat         # Production launcher
PREPROD_WS1-Mobile-Management-Tool.bat # Testing/staging version
```

### 🧠 Menu System
- Choose search type: **User ID** or **Serial Number**
- Select action: device info, tags, apps, etc.
- Output is displayed inline (some actions log to file)
- Timeout exits after 5 minutes of inactivity

---

## 🔐 Authentication Design

- **OAuth 2.0** flow with client credentials grant
- Tokens are retrieved via `https://na.uemauth.vmwservices.com/connect/token`
- Cached as JSON at: `Oauth Token/ws1_token_cache.json`
- Auto-renew logic refreshes tokens every hour based on timestamp delta

Each script imports a shared `Get-WS1Token` function unless overridden for standalone use.

---

## 🧪 Testing

Every major function has a PREPROD-safe version to:
- Validate token and API access
- Query without pushing changes (GET-only)
- Simulate device and user queries without making updates

Changelogs track stability of each script and validate code before it enters `PROD_ChangeLog.log`.

---

## 📈 Roadmap (Planned Features)
- GitHub-based packaging and version control
- CI/CD script testing pipeline
- PowerShell modules for import-based usage
- Export to CSV/JSON toggle per script
- WS1 Smart Group evaluation logic

---

## 📝 License
Internal use only during development.
MIT License will be attached once scripts are fully sanitized.

---

## 📣 Status
This tool is in active production use, with PREPROD branches available for staging. Contributions and feedback will be welcomed once the repo is fully published.

Stay tuned for the first tagged release!
