param(
  [ValidateSet("install","repair","doctor","status","scan","usage","projects","router-status","router-report","uninstall","start","stop")][string]$Action="install",
  [switch]$NoAutostart
)
$ErrorActionPreference="Stop"
$source=$PSScriptRoot
$home=if($env:CODEX_HOME){[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:CODEX_HOME))}else{Join-Path $HOME ".codex"}
$factory=Join-Path $home "smart-factory"
$startupDir=Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$startupCmd=Join-Path $startupDir "CodexSmartFactoryWatcher.cmd"

function Stop-Watcher {
  $pidFile=Join-Path $factory "state\watcher.pid"
  if(Test-Path $pidFile){
    $p=(Get-Content -Raw $pidFile).Trim()
    if($p -match '^\d+$'){Stop-Process -Id ([int]$p) -Force -ErrorAction SilentlyContinue;Start-Sleep -Milliseconds 250}
    Remove-Item -Force $pidFile -ErrorAction SilentlyContinue
  }
}
function Start-Watcher {
  $watch=Join-Path $factory "src\runtime\Watcher.ps1"
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `""+$watch+"`"")
}
function Install-Startup {
  New-Item -ItemType Directory -Force -Path $startupDir|Out-Null
  $watch=Join-Path $factory "src\runtime\Watcher.ps1"
  $body="@echo off`r`nstart `"`" /min powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$watch`"`r`n"
  [IO.File]::WriteAllText($startupCmd,$body,(New-Object Text.UTF8Encoding($false)))
}
function Copy-Package {
  New-Item -ItemType Directory -Force -Path $factory|Out-Null
  foreach($name in @("src","LICENSE","NOTICE.md","VERSION")){
    $src=Join-Path $source $name
    if(Test-Path $src){
      $dst=Join-Path $factory $name
      if(Test-Path $dst){Remove-Item -Recurse -Force $dst}
      Copy-Item -Recurse -Force $src $dst
    }
  }
}

if($Action -eq "install"){
  & (Join-Path $source "PRECHECK.ps1") -PackageRoot $source
  if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
  New-Item -ItemType Directory -Force -Path $home|Out-Null
  if(Test-Path $factory){Stop-Watcher}
  Copy-Package
  . (Join-Path $factory "src\runtime\Common.ps1")
  [void](Save-OriginalGlobalState)

  Write-Host "[1/5] Installing FULL global Core (not a tiny pointer)..."
  & (Join-Path $factory "src\runtime\Install-Global.ps1")|Out-Null

  Write-Host "[2/5] Discovering OLD + current Codex projects from surviving history..."
  & (Join-Path $factory "src\runtime\Scan-History.ps1") -Quiet | Out-Null

  Write-Host "[3/5] Initializing live model router..."
  . (Join-Path $factory "src\router\Router.ps1")
  [void](Get-RouterConfig)

  Write-Host "[4/5] Starting new-project watcher..."
  if(!$NoAutostart){Install-Startup;Start-Watcher;Start-Sleep -Milliseconds 700}
  else{Write-Host "Autostart skipped for this install."}

  Write-Host "[5/5] Status..."
  & (Join-Path $factory "src\runtime\Status.ps1") -Cwd (Get-Location).Path

  Write-Host ""
  Write-Host "[OK] Full Core is installed in global AGENTS.override.md."
  Write-Host "[OK] Existing global user instructions were preserved inside the composed override."
  Write-Host "[OK] Project AGENTS files were NOT overwritten or duplicated."
  Write-Host "[OK] Old projects were registered; new projects are observed automatically."
  Write-Host "[NEXT] Restart Codex once. Then ask: Check if you are boosted or no?"
  exit
}

if(!(Test-Path $factory)){throw "Smart Factory is not installed."}
. (Join-Path $factory "src\runtime\Common.ps1")

switch($Action){
  "repair"{
    & (Join-Path $factory "src\runtime\Install-Global.ps1")|Out-Null
    & (Join-Path $factory "src\runtime\Scan-History.ps1") -Quiet|Out-Null
    if(!$NoAutostart){Install-Startup;Start-Watcher}
    & (Join-Path $factory "src\runtime\Doctor.ps1")
  }
  "doctor"{& (Join-Path $factory "src\runtime\Doctor.ps1")}
  "status"{& (Join-Path $factory "src\runtime\Status.ps1") -Cwd (Get-Location).Path}
  "scan"{& (Join-Path $factory "src\runtime\Scan-History.ps1")}
  "usage"{& (Join-Path $factory "src\runtime\Token-Report.ps1") -Days 30}
  "projects"{
    $p=@(Get-ProjectRegistry|Sort-Object last_seen -Descending)
    if(!$p.Count){Write-Host "No projects registered.";break}
    $i=0;foreach($x in $p){$i++;Write-Host ("{0,3}. {1} | {2}" -f $i,$x.root,$x.last_seen)}
  }
  "router-status"{& (Join-Path $factory "src\router\Router-Status.ps1")}
  "router-report"{& (Join-Path $factory "src\router\Routing-Report.ps1")}
  "start"{Install-Startup;Start-Watcher;Write-Host "[OK] watcher started"}
  "stop"{Stop-Watcher;if(Test-Path $startupCmd){Remove-Item -Force $startupCmd};Write-Host "[OK] watcher stopped/disabled"}
  "uninstall"{
    Stop-Watcher
    if(Test-Path $startupCmd){Remove-Item -Force $startupCmd}
    $target=Join-Path $home "AGENTS.override.md"
    if(Test-Path $target){[void](Backup-File $target "uninstall-before-restore")}
    if(Restore-GlobalAfterUninstall){
      Write-Host "[OK] Smart Factory override removed; user-owned global instructions preserved."
    } else {
      throw "Original global-state snapshot is missing; refusing to guess how AGENTS.override.md should be restored. Restore from backups manually."
    }
    Write-Host "[OK] Smart Factory watcher/Core disabled. Backups/registry retained under $factory."
  }
}
