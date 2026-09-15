. (Join-Path $PSScriptRoot "Common.ps1")
$factory=Get-FactoryHome;$home=Get-CodexHome;$state=Join-Path $factory "state";New-Item -ItemType Directory -Force -Path $state|Out-Null;$pidFile=Join-Path $state "watcher.pid";$heartbeat=Join-Path $state "watcher.heartbeat"
$created=$false;$mutex=New-Object Threading.Mutex($true,"Local\CodexSmartFactoryFinalWatcher",([ref]$created));if(!$created){exit 0};Write-Utf8 $pidFile ([string]$PID)
function Beat{Write-Utf8 $heartbeat ((Get-Date).ToString("o"))}
$recent=@{}
function Process-Rollout([string]$Path){foreach($cwd in Get-CwdsFromRollout $Path){try{$root=Get-ProjectRoot $cwd;if(!$root){continue};$now=Get-Date;$last=$recent[$root];if($last -and (($now-$last).TotalSeconds -lt 30)){continue};$recent[$root]=$now;Save-ProjectRegistry $root $cwd "watcher";& (Join-Path $factory "src\runtime\Profile-Project.ps1") -Root $root|Out-Null;Write-FactoryLog "Observed Codex project: $root"}catch{Write-FactoryLog "Watcher error: $($_.Exception.Message)"}}}
try{
  Beat;$sessions=Join-Path $home "sessions";New-Item -ItemType Directory -Force -Path $sessions|Out-Null
  Get-ChildItem -LiteralPath $sessions -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 30|ForEach-Object{Process-Rollout $_.FullName}
  $fsw=New-Object IO.FileSystemWatcher;$fsw.Path=$sessions;$fsw.Filter="*.jsonl";$fsw.IncludeSubdirectories=$true;$fsw.NotifyFilter=[IO.NotifyFilters]'FileName, LastWrite, Size';$fsw.EnableRaisingEvents=$true
  Register-ObjectEvent $fsw Created -SourceIdentifier "CSF.Final.Created"|Out-Null;Register-ObjectEvent $fsw Changed -SourceIdentifier "CSF.Final.Changed"|Out-Null
  $lastMissionSweep=(Get-Date).AddMinutes(-10)
  while($true){
    Beat;$evt=Wait-Event -Timeout 5
    if($evt){try{Process-Rollout $evt.SourceEventArgs.FullPath}finally{Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue}}
    if(((Get-Date)-$lastMissionSweep).TotalMinutes -ge 5){
      $lastMissionSweep=Get-Date
      foreach($project in @(Get-ProjectRegistry)){try{if(!$project.root -or !(Test-Path -LiteralPath $project.root -PathType Container)){continue};$mission=Join-Path ([string]$project.root) ".codex-smart-factory\mission.json";if(Test-Path -LiteralPath $mission -PathType Leaf){& (Join-Path $factory "src\mission\Mission.ps1") watchdog -Root ([string]$project.root) -Quiet|Out-Null}}catch{Write-FactoryLog "Mission watchdog error for $($project.root): $($_.Exception.Message)"}}
    }
  }
}catch{Write-FactoryLog "Watcher fatal: $($_.Exception.Message)"}finally{try{Unregister-Event "CSF.Final.Created" -ErrorAction SilentlyContinue}catch{};try{Unregister-Event "CSF.Final.Changed" -ErrorAction SilentlyContinue}catch{};try{Remove-Item -Force $pidFile -ErrorAction SilentlyContinue}catch{};try{$mutex.ReleaseMutex();$mutex.Dispose()}catch{}}
