# 📱 Workspace ONE Mobile Management Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-lightgrey)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![WorkspaceONE](https://img.shields.io/badge/WorkspaceONE-API_Integrated-blueviolet.svg)](https://developer.vmware.com/apis/ws1/)
[![Release](https://img.shields.io/github/v/release/reponomadx/WS1-Mobile-Management-Tool.svg)](https://github.com/reponomadx/WS1-Mobile-Management-Tool/releases)
[![Code Size](https://img.shields.io/github/languages/code-size/reponomadx/WS1-Mobile-Management-Tool.svg)](https://github.com/reponomadx/WS1-Mobile-Management-Tool)

![Workspace ONE Tool](WS1-Mobile-Management-Tool.jpg)

A modular PowerShell-based utility for Workspace ONE, purpose-built to streamline mobile device administration in enterprise environments.

Originally developed in Bash for macOS workflows, this tool has evolved into a robust cross-functional PowerShell suite that enables IT teams to:

- Query device details and installed profiles  
- Reboot or wipe devices  
- Push app installations  
- Toggle Lost Mode  
- Manage tags, Smart Groups, and DEP profiles  

---

## 🛠️ Included Scripts

Each script is standalone but callable from a centralized CLI menu:

| Script | Function |
|--------|----------|
| `menu.ps1` | Interactive CLI menu |
| `Profiles.ps1` | Export installed configuration profiles |
| `Restart Device.ps1` | Reboot devices by serial |
| `Wipe.ps1` | Full or enterprise wipe |
| `Install App.ps1` | Push assigned apps to a device |
| `LostMode.ps1` | Enable or disable Lost Mode |
| `Tag Edit.ps1` | Add or remove device tags |
| `SmartGroup Lookup.ps1` | View Smart Group membership |
| `Assign or Unassign DEP.ps1` | Assign/unassign DEP profiles *(OAuth now supported)* |
| `EventLog.ps1` | Retrieve 1000 recent device event logs |
| `Delete Devices.ps1` | Remove devices from WS1 by serial or user |
| `Device Details.ps1` | Lookup basic device info |
| `Install Purchased App.ps1` | Deploy VPP apps by serial |
| `OauthRenew.ps1` | Renews OAuth token every hour |
| `Oauth - Renew.bat` | Wrapper script for Task Scheduler automation |

Also includes:  
`WS1-Mobile-Management-Tool.bat` → launcher to run the menu.

---

## 🔐 Authentication & Security (v1.2.0+)

All API calls use **OAuth 2.0** (`client_credentials` grant type) with **token reuse** across all scripts:

- Tokens are centrally stored at:  
  `\\HOST_SERVER\MobileManagementTool\Oauth Token\ws1_token_cache.json`
- **Client ID and secret** are no longer embedded in any script
- All Workspace ONE scripts check token age and read from this file
- If expired or missing, user is prompted to wait for hourly renewal

This eliminates write access requirements for general users and ensures all token logic is consolidated and secured.

---

## 🔁 OAuth Token Auto-Renewal

Tokens are refreshed hourly using Windows Task Scheduler.

### 🔧 Setup

| File | Description |
|------|-------------|
| `OauthRenew.ps1` | PowerShell script that renews the token |
| `Oauth - Renew.bat` | Batch wrapper for scheduler |
| `WS1 Oauth Token.xml` | Importable Task Scheduler config |
| `refresh.log` | Optional log for token renewals |

> 🛡️ Scripts now **require read-only access** to the shared token path — no write access needed.

---

## 🚀 Getting Started

1. Clone/download the repository  
2. Extract and customize configuration paths  
3. Place `WS1-Mobile-Management-Tool.bat` on a trusted IT workstation  
4. Run the tool from that system only (non-portable)  
5. Use menu or scripts individually  

---

## 📂 Output & Logs

By default, scripts write to the user’s `Downloads` folder or shared folders like:

- `device_profiles.csv`
- `WipedDevices.txt`
- `EventLog_YYYYMMDD.log`

---

## ✅ System Requirements

- PowerShell 5.1 or later  
- Workspace ONE API client credentials (stored securely)  
- Admin access to target devices (via WS1)  
- Internal access to shared script and token paths  

---

## 🔒 Host-Based Trust Model

This tool is designed to run only from **internal, IT-managed systems**.  
All scripts reference trusted shares such as: `\\HOST_SERVER\MobileManagementTool\`  
This prevents exfiltration or misuse on personal machines.

---

## 📢 Community & Version

Latest version: **v1.2.1**  
Source:  
🔗 [https://github.com/reponomadx/WS1-Mobile-Management-Tool](https://github.com/reponomadx/WS1-Mobile-Management-Tool)

Discussions feedback or issues welcome.

---

## 📄 License

MIT License — use, modify, distribute freely.  
No warranty or liability provided.
