param([string]$Cwd=(Get-Location).Path)
. (Join-Path $PSScriptRoot "Common.ps1")
$codexHome=Get-CodexHome
$factory=Get-FactoryHome
$version=(Read-Utf8 (Join-Path $factory "VERSION")).Trim()
if([string]::IsNullOrWhiteSpace($version)){$version="unknown"}
$override=Join-Path $codexHome "AGENTS.override.md"
$coreText=Read-Utf8 $override
$coreOn=$coreText -match 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'

$heartbeat=Join-Path $factory "state\watcher.heartbeat"
$watcher="OFF"
if(Test-Path $heartbeat){
  try{
    $age=((Get-Date)-[DateTimeOffset]::Parse((Read-Utf8 $heartbeat))).TotalSeconds
    if($age -lt 180){$watcher="ON"}else{$watcher="STALE"}
  }catch{$watcher="STALE"}
}

$router=Test-Path (Join-Path $factory "src\router\Route.ps1")
$missionRuntime=Test-Path (Join-Path $factory "src\mission\Mission.ps1")
$quotaGuard=Test-Path (Join-Path $factory "src\mission\QuotaCommon.ps1")
$profile="unknown"
try{
  . (Join-Path $factory "src\router\Router.ps1")
  $profile=[string](Get-RouterConfig).profile
}catch{}

$root=Get-ProjectRoot $Cwd
$registered="N/A"
$missionState="none"
if($root){
  if(@(Get-ProjectRegistry|Where-Object{$_.root -eq $root}).Count){$registered="ON"}else{$registered="OFF"}
  $missionPath=Join-Path $root ".codex-smart-factory\mission.json"
  if(Test-Path -LiteralPath $missionPath -PathType Leaf){
    try{$m=Get-Content -Raw -LiteralPath $missionPath|ConvertFrom-Json;$missionState=[string]$m.status}catch{$missionState="error"}
  }
}

$injected="UNKNOWN"
$matchingRollout=$null
$files=@()
try{
  $files=Get-ChildItem -LiteralPath $codexHome -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue|
    Where-Object{$_.FullName -notlike "$factory*"}|
    Sort-Object LastWriteTime -Descending|Select-Object -First 30
}catch{}

foreach($f in $files){
  $slice=Read-FileSlices $f.FullName 1048576 262144
  if(!$slice){continue}
  $cwdMatch=$false
  foreach($c in Get-CwdsFromRollout $f.FullName){
    if($c -eq $Cwd -or ($root -and $c.StartsWith($root,[StringComparison]::OrdinalIgnoreCase))){$cwdMatch=$true;break}
  }
  if(!$cwdMatch){continue}
  $matchingRollout=$f.FullName
  if($slice -match 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'){$injected="YES"}else{$injected="NO"}
  break
}

$state="DEGRADED"
if($coreOn -and $router -and $missionRuntime -and $quotaGuard -and $watcher -eq "ON" -and $injected -eq "YES"){$state="YES"}
elseif($coreOn -and $injected -ne "YES"){$state="PENDING_RESTART"}

Write-Output ("BOOSTED: {0} | SmartFactory={1} | GlobalCore={2} | SessionInjected={3} | Router={4}({5}) | Mission={6}({7}) | QuotaGuard={8} | Watcher={9} | ProjectRegistry={10}" -f $state,$version,$(if($coreOn){"ON"}else{"OFF"}),$injected,$(if($router){"ON"}else{"OFF"}),$profile,$(if($missionRuntime){"ON"}else{"OFF"}),$missionState,$(if($quotaGuard){"ON"}else{"OFF"}),$watcher,$registered)
Write-Output ("CODEX_HOME: "+$codexHome)
if($root){Write-Output ("Project: "+$root)}
if($matchingRollout){Write-Output ("Evidence rollout: "+$matchingRollout)}
