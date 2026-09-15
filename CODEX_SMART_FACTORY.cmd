@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Codex Smart Factory Final v1.1.1

call :resolve_powershell
if errorlevel 1 (
  echo.
  echo [ERROR] No usable PowerShell host was found.
  echo Checked Windows PowerShell, Sysnative, PowerShell 7, and PATH fallbacks.
  echo Windows PowerShell normally exists at:
  echo   %%SystemRoot%%\System32\WindowsPowerShell\v1.0\powershell.exe
  echo.
  pause
  exit /b 9009
)

if /I "%~1"=="--self-test" (
  echo [OK] PowerShell host: "%PS_EXE%"
  "%PS_EXE%" -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
  exit /b %errorlevel%
)

:menu
cls
echo ================================================================================
echo                    CODEX SMART FACTORY - FINAL v1.1.1
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
if /I "%CH%"=="1" call :run_ps "%~dp0INSTALL.ps1" install
if /I "%CH%"=="2" call :run_ps "%~dp0INSTALL.ps1" status
if /I "%CH%"=="3" call :run_ps "%~dp0INSTALL.ps1" doctor
if /I "%CH%"=="4" call :run_ps "%~dp0INSTALL.ps1" repair
if /I "%CH%"=="5" call :run_ps "%~dp0INSTALL.ps1" projects
if /I "%CH%"=="6" call :run_ps "%~dp0INSTALL.ps1" usage
if /I "%CH%"=="7" call :run_ps "%~dp0INSTALL.ps1" router-status
if /I "%CH%"=="8" call :run_ps "%~dp0src\router\Set-Profile.ps1" -Profile token-saver
if /I "%CH%"=="9" call :run_ps "%~dp0src\router\Set-Profile.ps1" -Profile balanced
if /I "%CH%"=="A" call :run_ps "%~dp0src\router\Set-Profile.ps1" -Profile max-quality
if /I "%CH%"=="B" call :run_ps "%~dp0INSTALL.ps1" router-report
if /I "%CH%"=="C" call :run_ps "%~dp0INSTALL.ps1" start
if /I "%CH%"=="D" call :run_ps "%~dp0INSTALL.ps1" stop
if /I "%CH%"=="E" (
  echo.
  echo This removes only Smart Factory managed global Core and watcher.
  echo Preserved pre-existing global instructions are restored.
  set /p U=Type YES to continue:
  if /I "%U%"=="YES" call :run_ps "%~dp0INSTALL.ps1" uninstall
)
if "%CH%"=="0" exit /b 0
echo.
pause
goto menu

:run_ps
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File %*
exit /b %errorlevel%

:resolve_powershell
set "PS_EXE="
if defined SystemRoot if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not defined PS_EXE if defined SystemRoot if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not defined PS_EXE if defined ProgramFiles if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PS_EXE for /f "delims=" %%P in ('where pwsh.exe 2^>nul') do if not defined PS_EXE set "PS_EXE=%%P"
if not defined PS_EXE for /f "delims=" %%P in ('where powershell.exe 2^>nul') do if not defined PS_EXE set "PS_EXE=%%P"
if not defined PS_EXE exit /b 1
exit /b 0
