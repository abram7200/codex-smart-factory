@echo off
setlocal
cd /d "%~dp0"
title Codex Smart Factory Final v1.1.0
:menu
cls
echo ================================================================================
echo                    CODEX SMART FACTORY - FINAL v1.1.0
echo      FULL ALWAYS-ON CORE / OLD+NEW PROJECTS / SMART MODEL ROUTER / SELF-CHECK
echo ================================================================================
echo.
echo 1. FULL INSTALL / UPDATE
echo 2. BOOST STATUS
echo 3. DOCTOR / HEALTH CHECK
echo 4. REPAIR + RESCAN ALL OLD PROJECT HISTORY
echo 5. SHOW KNOWN OLD + NEW PROJECTS
echo 6. TOKEN USAGE REPORT - 30 DAYS
echo 7. MODEL ROUTER STATUS / LIVE CATALOG
echo 8. ROUTER PROFILE: TOKEN-SAVER
echo 9. ROUTER PROFILE: BALANCED  [recommended]
echo A. ROUTER PROFILE: MAX-QUALITY
echo B. ROUTING DECISION REPORT
echo C. START WATCHER
echo D. STOP WATCHER
echo E. UNINSTALL MANAGED LAYER
echo 0. EXIT
echo.
set /p CH=Choose:
if /I "%CH%"=="1" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" install
if /I "%CH%"=="2" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" status
if /I "%CH%"=="3" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" doctor
if /I "%CH%"=="4" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" repair
if /I "%CH%"=="5" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" projects
if /I "%CH%"=="6" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" usage
if /I "%CH%"=="7" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" router-status
if /I "%CH%"=="8" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Set-Profile.ps1" -Profile token-saver
if /I "%CH%"=="9" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Set-Profile.ps1" -Profile balanced
if /I "%CH%"=="A" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Set-Profile.ps1" -Profile max-quality
if /I "%CH%"=="B" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" router-report
if /I "%CH%"=="C" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" start
if /I "%CH%"=="D" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" stop
if /I "%CH%"=="E" (
  echo.
  echo This removes only Smart Factory managed global Core and watcher.
  echo Preserved pre-existing global instructions are restored.
  set /p U=Type YES to continue:
  if /I "%U%"=="YES" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALL.ps1" uninstall
)
if "%CH%"=="0" exit /b 0
echo.
pause
goto menu
