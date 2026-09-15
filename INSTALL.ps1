param(
  [ValidateSet("install","repair","doctor","status","scan","usage","projects","router-status","router-report","uninstall","start","stop")][string]$Action="install",
  [switch]$NoAutostart
)
$ErrorActionPreference="Stop"
$source=$PSScriptRoot
$codexHome=if($env:CODEX_HOME){[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:CODEX_HOME))}else{Join-Path $HOME ".codex"}
$factory=Join-Path $codexHome "smart-factory"
$startupDir=Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$startupCmd=Join-Path $startupDir "CodexSmartFactoryWatcher.cmd"

function Get-PowerShellHostPath {
  try {
    $current=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if($current -and (Test-Path -LiteralPath $current -PathType Leaf)){
      $name=[IO.Path]::GetFileName($current).ToLowerInvariant()
      if($name -in @("powershell.exe","pwsh.exe")){return [IO.Path]::GetFullPath($current)}
    }
  } catch {}

  $candidates=@()
  if($PSHOME){
    $candidates += (Join-Path $PSHOME "powershell.exe")
    $candidates += (Join-Path $PSHOME "pwsh.exe")
  }
  if($env:SystemRoot){
    $candidates += (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe")
    $candidates += (Join-Path $env:SystemRoot "Sysnative\WindowsPowerShell\v1.0\powershell.exe")
  }
  if($env:ProgramFiles){$candidates += (Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe")}

  foreach($candidate in $candidates){
    if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return [IO.Path]::GetFullPath($candidate)}
  }
  foreach($name in @("pwsh.exe","powershell.exe")){
    try{
      $cmd=Get-Command $name -ErrorAction Stop
      if($cmd.Source -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)){return [IO.Path]::GetFullPath($cmd.Source)}
    }catch{}
  }
  throw "No usable PowerShell host was found."
}

function Get-WatcherHealth {
  $pidFile=Join-Path $factory "state\watcher.pid"
  $heartbeat=Join-Path $factory "state\watcher.heartbeat"
  $pidValue=$null
  $alive=$false
  $fresh=$false
  $ageSeconds=$null

  if(Test-Path -LiteralPath $pidFile -PathType Leaf){
    try{
      $raw=(Get-Content -Raw -LiteralPath $pidFile).Trim()
      if($raw -match '^\d+$'){
        $pidValue=[int]$raw
        $proc=Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if($proc){$alive=$true}
      }
    }catch{}
  }

  if(Test-Path -LiteralPath $heartbeat -PathType Leaf){
    try{
      $stamp=[DateTimeOffset]::Parse((Get-Content -Raw -LiteralPath $heartbeat).Trim())
      $ageSeconds=((Get-Date)-$stamp.LocalDateTime).TotalSeconds
      if($ageSeconds -ge 0 -and $ageSeconds -lt 20){$fresh=$true}
    }catch{}
  }

  [pscustomobject]@{Pid=$pidValue;Alive=$alive;Fresh=$fresh;AgeSeconds=$ageSeconds}
}

function Wait-WatcherHealthy([int]$TimeoutSeconds=15) {
  $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $health=Get-WatcherHealth
    if($health.Alive -and $health.Fresh){return $true}
    Start-Sleep -Milliseconds 250
  } while((Get-Date) -lt $deadline)
  return $false
}

function Stop-Watcher {
  $pidFile=Join-Path $factory "state\watcher.pid"
  if(Test-Path -LiteralPath $pidFile -PathType Leaf){
    try{
      $raw=(Get-Content -Raw -LiteralPath $pidFile).Trim()
      if($raw -match '^\d+$'){
        $watcherPid=[int]$raw
        $safeToStop=$false
        try{
          $process=Get-CimInstance Win32_Process -Filter ("ProcessId = "+$watcherPid) -ErrorAction Stop
          if($process -and $process.CommandLine -and $process.CommandLine -like "*Watcher.ps1*"){$safeToStop=$true}
        }catch{}
        if($safeToStop){Stop-Process -Id $watcherPid -Force -ErrorAction SilentlyContinue;Start-Sleep -Milliseconds 300}
      }
    }catch{}
    Remove-Item -Force -LiteralPath $pidFile -ErrorAction SilentlyContinue
  }
}

function Start-Watcher {
  $watch=Join-Path $factory "src\runtime\Watcher.ps1"
  if(!(Test-Path -LiteralPath $watch -PathType Leaf)){throw "Watcher script not found: $watch"}
  $psExe=Get-PowerShellHostPath
  $heartbeat=Join-Path $factory "state\watcher.heartbeat"

  Stop-Watcher
  Remove-Item -Force -LiteralPath $heartbeat -ErrorAction SilentlyContinue

  $args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$watch`""
  $proc=Start-Process -FilePath $psExe -WindowStyle Hidden -ArgumentList $args -PassThru

  if(!(Wait-WatcherHealthy 15)){
    $exited=$false
    try{$proc.Refresh();$exited=$proc.HasExited}catch{}
    $log=Join-Path $factory "logs\factory.log"
    throw ("Watcher did not become healthy within 15 seconds. ProcessExited="+$exited+". Check "+$log)
  }
}

function Install-Startup {
  New-Item -ItemType Directory -Force -Path $startupDir|Out-Null
  $watch=Join-Path $factory "src\runtime\Watcher.ps1"
  $psExe=Get-PowerShellHostPath
  $body="@echo off`r`nstart `"`" /min `"$psExe`" -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$watch`"`r`n"
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
  New-Item -ItemType Directory -Force -Path $codexHome|Out-Null
  if(Test-Path $factory){Stop-Watcher}
  Copy-Package
  . (Join-Path $factory "src\runtime\Common.ps1")
  [void](Save-OriginalGlobalState)

  Write-Host "[1/5] Installing FULL global Core..."
  & (Join-Path $factory "src\runtime\Install-Global.ps1")|Out-Null

  Write-Host "[2/5] Discovering OLD + current Codex projects..."
  & (Join-Path $factory "src\runtime\Scan-History.ps1") -Quiet | Out-Null

  Write-Host "[3/5] Initializing live model router..."
  . (Join-Path $factory "src\router\Router.ps1")
  [void](Get-RouterConfig)

  Write-Host "[4/5] Starting project watcher..."
  if(!$NoAutostart){
    Install-Startup
    Start-Watcher
    Write-Host "[OK] Watcher heartbeat verified."
  }else{
    Write-Host "Autostart skipped for this install."
  }

  Write-Host "[5/5] Status..."
  & (Join-Path $factory "src\runtime\Status.ps1") -Cwd $codexHome

  Write-Host ""
  Write-Host "[OK] Smart Factory install/update completed."
  Write-Host "[OK] Existing global and project AGENTS rules are preserved."
  Write-Host "[OK] Old projects registered; new projects are observed automatically."
  Write-Host "[NEXT] Restart Codex once if this Core was not already injected into the current session."
  exit 0
}

if(!(Test-Path $factory)){throw "Smart Factory is not installed. Run CODEX_SMART_FACTORY.cmd first."}
. (Join-Path $factory "src\runtime\Common.ps1")

switch($Action){
  "repair"{
    & (Join-Path $factory "src\runtime\Install-Global.ps1")|Out-Null
    & (Join-Path $factory "src\runtime\Scan-History.ps1") -Quiet|Out-Null
    if(!$NoAutostart){Install-Startup;Start-Watcher;Write-Host "[OK] Watcher heartbeat verified."}
    & (Join-Path $factory "src\runtime\Doctor.ps1") -Cwd $codexHome
  }
  "doctor"{& (Join-Path $factory "src\runtime\Doctor.ps1") -Cwd $codexHome}
  "status"{& (Join-Path $factory "src\runtime\Status.ps1") -Cwd $codexHome}
  "scan"{& (Join-Path $factory "src\runtime\Scan-History.ps1")}
  "usage"{& (Join-Path $factory "src\runtime\Token-Report.ps1") -Days 30}
  "projects"{
    $p=@(Get-ProjectRegistry|Sort-Object last_seen -Descending)
    if(!$p.Count){Write-Host "No projects registered.";break}
    $i=0;foreach($x in $p){$i++;Write-Host ("{0,3}. {1} | {2}" -f $i,$x.root,$x.last_seen)}
  }
  "router-status"{& (Join-Path $factory "src\router\Router-Status.ps1")}
  "router-report"{& (Join-Path $factory "src\router\Routing-Report.ps1")}
  "start"{Install-Startup;Start-Watcher;Write-Host "[OK] watcher started and heartbeat verified"}
  "stop"{Stop-Watcher;if(Test-Path $startupCmd){Remove-Item -Force $startupCmd};Write-Host "[OK] watcher stopped/disabled"}
  "uninstall"{
    Stop-Watcher
    if(Test-Path $startupCmd){Remove-Item -Force $startupCmd}
    $target=Join-Path $codexHome "AGENTS.override.md"
    if(Test-Path $target){[void](Backup-File $target "uninstall-before-restore")}
    if(Restore-GlobalAfterUninstall){
      Write-Host "[OK] Smart Factory managed global layer removed; user-owned instructions preserved."
    } else {
      throw "Original global-state snapshot is missing; refusing to guess how AGENTS.override.md should be restored. Restore from backups manually."
    }
    Write-Host "[OK] Watcher disabled. Backups/registry retained under $factory."
  }
}
