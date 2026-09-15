@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"

call :resolve_powershell
if errorlevel 1 (
  echo [ERROR] No usable PowerShell host was found.
  exit /b 9009
)

set "TASK=%*"
if "%TASK%"=="" (
  echo Enter a Codex task:
  set /p TASK=^> 
)
if "%TASK%"=="" exit /b 1
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Smart-Exec.ps1" -Task "%TASK%" -Cwd "%CD%"
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
