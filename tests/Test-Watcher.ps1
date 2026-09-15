param([string]$RepoRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference="Stop"
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("csf-watcher-"+[guid]::NewGuid().ToString("N"))
$codexHome=Join-Path $tmp "codex-home"
$appData=Join-Path $tmp "appdata"
New-Item -ItemType Directory -Force -Path $codexHome,$appData|Out-Null
$oldCodex=$env:CODEX_HOME
$oldAppData=$env:APPDATA
$env:CODEX_HOME=$codexHome
$env:APPDATA=$appData
try{
  & (Join-Path $RepoRoot "INSTALL.ps1") install -NoAutostart | Out-Null
  & (Join-Path $RepoRoot "INSTALL.ps1") start | Out-Null

  $pidFile=Join-Path $codexHome "smart-factory\state\watcher.pid"
  $heartbeat=Join-Path $codexHome "smart-factory\state\watcher.heartbeat"
  if(!(Test-Path -LiteralPath $pidFile -PathType Leaf)){throw "watcher pid file missing"}
  if(!(Test-Path -LiteralPath $heartbeat -PathType Leaf)){throw "watcher heartbeat missing"}

  $pidValue=(Get-Content -Raw -LiteralPath $pidFile).Trim()
  if($pidValue -notmatch '^\d+$'){throw "watcher pid invalid"}
  $proc=Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
  if(!$proc){throw "watcher process not alive"}

  $stamp=[DateTimeOffset]::Parse((Get-Content -Raw -LiteralPath $heartbeat).Trim())
  $age=((Get-Date)-$stamp.LocalDateTime).TotalSeconds
  if($age -lt 0 -or $age -gt 20){throw ("watcher heartbeat stale: "+$age)}

  & (Join-Path $RepoRoot "INSTALL.ps1") stop | Out-Null
  Start-Sleep -Milliseconds 400
  $proc=Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
  if($proc){throw "watcher process still alive after stop"}

  Write-Host "PASS watcher absolute-host startup / heartbeat / stop"
}finally{
  try{& (Join-Path $RepoRoot "INSTALL.ps1") stop | Out-Null}catch{}
  if($null -eq $oldCodex){Remove-Item Env:\CODEX_HOME -ErrorAction SilentlyContinue}else{$env:CODEX_HOME=$oldCodex}
  if($null -eq $oldAppData){Remove-Item Env:\APPDATA -ErrorAction SilentlyContinue}else{$env:APPDATA=$oldAppData}
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
