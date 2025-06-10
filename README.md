# 📱 Workspace ONE Mobile Management Tool

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-lightgrey)](https://microsoft.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![WorkspaceONE](https://img.shields.io/badge/WorkspaceONE-API_Integrated-blueviolet.svg)](https://developer.vmware.com/apis/ws1/)
[![GroundControl](https://img.shields.io/badge/GroundControl-Compatible-yellow.svg)](https://www.imprivata.com/groundcontrol)

The Workspace ONE Mobile Management Tool is a modular, PowerShell-based utility built to streamline mobile device administration in enterprise environments.

Originally developed in Bash for macOS support workflows, this tool has evolved into a cross-functional PowerShell suite that empowers IT teams to:

- Query device details and installed profiles
- Reboot or wipe devices
- Push app installations
- Toggle Lost Mode
- Manage tags, DEP profiles, and more

---
## 🛠️ Included Scripts

Each script is self-contained and callable independently, or via a centralized menu:

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
| `Assign or Unassign DEP.ps1` | Assign/unassign DEP profiles |
| `EventLog.ps1` | Retrieve 1000 recent device event logs |
| `Delete Devices.ps1` | Remove devices from WS1 by serial or user |
| `Device Details.ps1` | Lookup basic device info |
| `Install Purchased App.ps1` | Deploy VPP apps by serial |

Also includes:  
`WS1-Mobile-Management-Tool.bat` → launcher that executes the menu script.

---
## 🚀 Getting Started

1. Clone or download the release from GitHub
2. Extract the `.zip` to a known location
3. Update all necessary variables for your enviornment
3. Place `WS1-Mobile-Management-Tool.bat` on your desktop (or trusted path)
4. Double-click to launch the menu system
5. Select the operation you'd like to perform

---
## 🔐 Authentication & Security

All API calls are secured using **OAuth 2.0** (`client_credentials` grant type):

- Tokens are requested from:  
  `https://na.uemauth.vmwservices.com/connect/token`
- Cached locally at:  
  `ws1_token_cache.json`
- Automatically refreshed every hour

🔒 **Host-Based Access Restriction**

- The tool is restricted to **trusted IT-managed workstations**
- All scripts depend on internal network paths like:  
  `\HOST_SERVER\MobileManagementTool\`
- `.bat` launcher is not portable and must be used from designated consoles

This prevents misuse from personal machines and secures all token usage to limited endpoints.

---
## 📂 Output & Logs

Scripts output to the user’s `Downloads` folder by default or to shared folders such as:

Filenames include:
- `device_profiles.csv`
- `WipedDevices.txt`

---
## ✅ System Requirements

- PowerShell 5.1+ (Windows)
- Workspace ONE API access
- Admin permissions to target devices

---
## 🤝 Contributing / Forking

Pull requests are welcome. Please sanitize credentials before pushing updates.  
Issues can be submitted directly on GitHub under the [Issues tab](https://github.com/reponomadx/WS1-Mobile-Management-Tool/issues).

---
## 📢 Publishing & Community

This release is published and verified at:

🔗 [https://github.com/reponomadx/WS1-Mobile-Management-Tool/tree/v1.0.0](https://github.com/reponomadx/WS1-Mobile-Management-Tool/tree/v1.0.0)

If you're viewing this from Reddit or another channel, you're encouraged to reply to the original post with questions or deployment success stories.

---
## 📄 License

MIT License – Free to use, modify, and share. No warranty or guarantee provided.
