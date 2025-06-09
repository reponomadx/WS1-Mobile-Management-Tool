@echo off
set SCRIPT=\\HOST_SERVER\MobileManagementTool\menu\menu.ps1

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%SCRIPT%' -Raw)"
pause
