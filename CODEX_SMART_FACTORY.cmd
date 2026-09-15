@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Astra AGI Harness for Codex - Smart Factory v1.1.2

call :resolve_powershell
if errorlevel 1 (
  echo.
  echo [ERROR] No usable PowerShell host was found.
  echo Checked Windows PowerShell, Sysnative, PowerShell 7, and PATH fallbacks.
  echo Expected Windows PowerShell path:
  echo   %%SystemRoot%%\System32\WindowsPowerShell\v1.0\powershell.exe
  echo.
  pause
  exit /b 9009
)

if /I "%~1"=="--self-test" goto self_test
if /I "%~1"=="status" goto status
if /I "%~1"=="doctor" goto doctor
if /I "%~1"=="repair" goto repair
if /I "%~1"=="uninstall" goto uninstall
if /I "%~1"=="task" goto task
if /I "%~1"=="profile" goto profile
if /I "%~1"=="help" goto help
if /I "%~1"=="--help" goto help
if not "%~1"=="" goto help

goto auto

:auto
cls
echo ================================================================================
echo              ASTRA AGI HARNESS FOR CODEX - SMART AUTO SETUP v1.1.2
echo                 Codex Windows App + Codex CLI on Windows
echo ================================================================================
echo.
echo [AUTO] PowerShell: "%PS_EXE%"
echo [AUTO] Running precheck, install/update, project discovery, watcher, router and status...
echo.
call :run_ps "%~dp0INSTALL.ps1" install
if errorlevel 1 goto failed

echo.
echo [AUTO] Running final doctor...
call :run_ps "%~dp0INSTALL.ps1" doctor
if errorlevel 1 goto failed

echo.
echo ================================================================================
echo [READY] Smart Factory setup/update completed.
echo [NEXT] Restart Codex once if this was a fresh install or Core update.
echo [TEST] In Codex ask: Check if you are boosted or no?
echo ================================================================================
echo.
pause
exit /b 0

:status
call :run_ps "%~dp0INSTALL.ps1" status
exit /b %errorlevel%

:doctor
call :run_ps "%~dp0INSTALL.ps1" doctor
exit /b %errorlevel%

:repair
call :run_ps "%~dp0INSTALL.ps1" repair
exit /b %errorlevel%

:uninstall
echo This removes only the Smart Factory managed layer and watcher.
echo User-owned AGENTS instructions are preserved.
set /p CONFIRM=Type YES to continue: 
if /I not "%CONFIRM%"=="YES" exit /b 0
call :run_ps "%~dp0INSTALL.ps1" uninstall
exit /b %errorlevel%

:task
if "%~2"=="" (
  echo Usage: CODEX_SMART_FACTORY.cmd task "your task"
  exit /b 2
)
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Smart-Exec.ps1" -Task "%~2" -Cwd "%CD%"
exit /b %errorlevel%

:profile
if /I "%~2"=="token-saver" goto set_profile
if /I "%~2"=="balanced" goto set_profile
if /I "%~2"=="max-quality" goto set_profile
echo Usage: CODEX_SMART_FACTORY.cmd profile token-saver^|balanced^|max-quality
exit /b 2

:set_profile
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Set-Profile.ps1" -Profile "%~2"
exit /b %errorlevel%

:self_test
echo [OK] Sole launcher: CODEX_SMART_FACTORY.cmd
echo [OK] PowerShell host: "%PS_EXE%"
"%PS_EXE%" -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
exit /b %errorlevel%

:help
echo Codex Smart Factory has one smart Windows entrypoint.
echo.
echo Double-click with no arguments:
echo   Automatically INSTALLS or UPDATES, repairs state, discovers projects,
echo   starts and verifies the watcher, initializes routing, and runs health checks.
echo.
echo Optional advanced commands:
echo   CODEX_SMART_FACTORY.cmd status
echo   CODEX_SMART_FACTORY.cmd doctor
echo   CODEX_SMART_FACTORY.cmd repair
echo   CODEX_SMART_FACTORY.cmd task "your task"
echo   CODEX_SMART_FACTORY.cmd profile balanced
echo   CODEX_SMART_FACTORY.cmd uninstall
echo.
exit /b 0

:failed
echo.
echo [FAILED] Smart Factory did not complete successfully.
echo Run this same CMD again; it is safe and idempotent.
echo If it still fails, run: CODEX_SMART_FACTORY.cmd doctor
echo.
pause
exit /b 1

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
