@echo off
setlocal
cd /d "%~dp0"
set "TASK=%*"
if "%TASK%"=="" (
  echo Enter a Codex task:
  set /p TASK=^> 
)
if "%TASK%"=="" exit /b 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\router\Smart-Exec.ps1" -Task "%TASK%" -Cwd "%CD%"
