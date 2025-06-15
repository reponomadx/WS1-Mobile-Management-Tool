:: --------------------------------
:: SCRIPT PURPOSE
:: --------------------------------
:: This batch script logs the start and end of an OAuth token renewal process
:: and runs a PowerShell script to perform the renewal. It is intended to be
:: called by a scheduled task that executes hourly.

@echo off
set LOG=C:\Path\To\WS1_OauthToken_Renewal\refresh.log

echo [%DATE% %TIME%] Starting token renewal... >> %LOG%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\WS1_OauthToken_Renewal\OauthRenew.ps1" >> %LOG% 2>&1

timeout /t 5 /nobreak >nul

echo [%DATE% %TIME%] Done. >> %LOG%