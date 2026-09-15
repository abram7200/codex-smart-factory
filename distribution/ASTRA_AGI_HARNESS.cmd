@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Astra AGI Harness for Codex - One File Installer v1.1.3

set "CSF_VERSION=1.1.3"
set "CSF_TAG=v1.1.3"
set "CSF_URL=https://github.com/abram7200/codex-smart-factory/archive/refs/tags/%CSF_TAG%.zip"

call :resolve_powershell
if errorlevel 1 (
  echo [ERROR] No usable PowerShell host was found.
  echo Expected Windows PowerShell at %%SystemRoot%%\System32\WindowsPowerShell\v1.0\powershell.exe
  pause
  exit /b 9009
)

if /I "%~1"=="status" goto installed_status
if /I "%~1"=="doctor" goto installed_doctor
if /I "%~1"=="repair" goto repair
if /I "%~1"=="uninstall" goto uninstall
if /I "%~1"=="profile" goto installed_profile
if /I "%~1"=="task" goto installed_task
if /I "%~1"=="help" goto help
if /I "%~1"=="--help" goto help
if not "%~1"=="" goto help

goto install_update

:install_update
cls
echo ================================================================================
echo              ASTRA AGI HARNESS FOR CODEX - ONE FILE SETUP v%CSF_VERSION%
echo                     Codex Windows App + Codex CLI
echo ================================================================================
echo.
echo [AUTO] PowerShell: "%PS_EXE%"
echo [AUTO] Downloading verified release %CSF_TAG% to a temporary folder only.
echo [AUTO] Existing Smart Factory state and user AGENTS instructions are preserved.
echo.
call :prepare_package
if errorlevel 1 goto failed

"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PKG_ROOT%\INSTALL.ps1" install
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  call :cleanup
  goto failed
)

echo.
echo [AUTO] Final doctor...
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PKG_ROOT%\INSTALL.ps1" doctor
set "RC=%ERRORLEVEL%"
call :cleanup
if not "%RC%"=="0" goto failed

echo.
echo ================================================================================
echo [READY] v%CSF_VERSION% installed/updated successfully.
echo [CLEAN] Temporary download and extraction removed.
echo [NEXT] Restart Codex once after a fresh install/Core update.
echo [TEST] In Codex ask: Check if you are boosted or no?
echo ================================================================================
echo.
pause
exit /b 0

:repair
call :prepare_package
if errorlevel 1 goto failed
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PKG_ROOT%\INSTALL.ps1" repair
set "RC=%ERRORLEVEL%"
call :cleanup
exit /b %RC%

:uninstall
echo This removes only the Smart Factory managed layer and watcher.
echo User-owned AGENTS instructions are preserved.
set /p "CONFIRM=Type YES to continue: "
if /I not "%CONFIRM%"=="YES" exit /b 0
call :prepare_package
if errorlevel 1 goto failed
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PKG_ROOT%\INSTALL.ps1" uninstall
set "RC=%ERRORLEVEL%"
call :cleanup
exit /b %RC%

:installed_status
call :runtime_root
if not exist "%RUNTIME%\src\runtime\Status.ps1" (
  echo [INFO] Smart Factory is not installed yet. Double-click this file first.
  exit /b 2
)
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUNTIME%\src\runtime\Status.ps1" -Cwd "%CD%"
exit /b %ERRORLEVEL%

:installed_doctor
call :runtime_root
if not exist "%RUNTIME%\src\runtime\Doctor.ps1" (
  echo [INFO] Smart Factory is not installed yet. Double-click this file first.
  exit /b 2
)
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUNTIME%\src\runtime\Doctor.ps1" -Cwd "%CD%"
exit /b %ERRORLEVEL%

:installed_profile
if "%~2"=="" goto help
call :runtime_root
if not exist "%RUNTIME%\src\router\Set-Profile.ps1" exit /b 2
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUNTIME%\src\router\Set-Profile.ps1" -Profile "%~2"
exit /b %ERRORLEVEL%

:installed_task
if "%~2"=="" goto help
call :runtime_root
if not exist "%RUNTIME%\src\router\Smart-Exec.ps1" exit /b 2
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUNTIME%\src\router\Smart-Exec.ps1" -Task "%~2" -Cwd "%CD%"
exit /b %ERRORLEVEL%

:runtime_root
set "RUNTIME=%USERPROFILE%\.codex\smart-factory"
if defined CODEX_HOME set "RUNTIME=%CODEX_HOME%\smart-factory"
exit /b 0

:prepare_package
call :cleanup
set "CSF_TEMP=%TEMP%\AstraAGIHarness-%RANDOM%-%RANDOM%"
set "CSF_ZIP=%CSF_TEMP%\package.zip"
set "CSF_EXTRACT=%CSF_TEMP%\extract"
mkdir "%CSF_TEMP%" >nul 2>&1
mkdir "%CSF_EXTRACT%" >nul 2>&1

echo [1/4] Downloading %CSF_TAG%...
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%CSF_URL%' -OutFile '%CSF_ZIP%'"
if errorlevel 1 exit /b 1

echo [2/4] Extracting temporary package...
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%CSF_ZIP%' -DestinationPath '%CSF_EXTRACT%' -Force"
if errorlevel 1 exit /b 1

for /d %%D in ("%CSF_EXTRACT%\codex-smart-factory-*") do if not defined PKG_ROOT set "PKG_ROOT=%%~fD"
if not defined PKG_ROOT (
  echo [ERROR] Downloaded package root was not found.
  exit /b 1
)

echo [3/4] Verifying package identity...
if not exist "%PKG_ROOT%\VERSION" exit /b 1
set /p "DOWNLOADED_VERSION="<"%PKG_ROOT%\VERSION"
if /I not "%DOWNLOADED_VERSION%"=="%CSF_VERSION%" (
  echo [ERROR] Version mismatch. Expected %CSF_VERSION%, got %DOWNLOADED_VERSION%.
  exit /b 1
)
if not exist "%PKG_ROOT%\INSTALL.ps1" exit /b 1
if not exist "%PKG_ROOT%\src\CORE_AGENTS.md" exit /b 1

echo [4/4] Running package precheck...
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PKG_ROOT%\PRECHECK.ps1" -PackageRoot "%PKG_ROOT%"
if errorlevel 1 exit /b 1
exit /b 0

:cleanup
if defined CSF_TEMP if exist "%CSF_TEMP%" rmdir /s /q "%CSF_TEMP%" >nul 2>&1
set "CSF_TEMP="
set "CSF_ZIP="
set "CSF_EXTRACT="
set "PKG_ROOT="
set "DOWNLOADED_VERSION="
exit /b 0

:resolve_powershell
set "PS_EXE="
if defined SystemRoot if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not defined PS_EXE if defined SystemRoot if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not defined PS_EXE if defined ProgramFiles if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PS_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
if not defined PS_EXE for /f "delims=" %%P in ('where pwsh.exe 2^>nul') do if not defined PS_EXE set "PS_EXE=%%P"
if not defined PS_EXE for /f "delims=" %%P in ('where powershell.exe 2^>nul') do if not defined PS_EXE set "PS_EXE=%%P"
if not defined PS_EXE exit /b 1
exit /b 0

:help
echo Astra AGI Harness for Codex v%CSF_VERSION%
echo.
echo Double-click: install/update automatically.
echo Optional:
echo   ASTRA_AGI_HARNESS.cmd status
echo   ASTRA_AGI_HARNESS.cmd doctor
echo   ASTRA_AGI_HARNESS.cmd repair
echo   ASTRA_AGI_HARNESS.cmd task "your task"
echo   ASTRA_AGI_HARNESS.cmd profile balanced
echo   ASTRA_AGI_HARNESS.cmd uninstall
exit /b 0

:failed
echo.
echo [FAILED] Setup did not finish safely.
echo Existing persistent Smart Factory state was not intentionally removed.
echo.
call :cleanup
pause
exit /b 1
