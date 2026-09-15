param([string]$Cwd=(Get-Location).Path)
. (Join-Path $PSScriptRoot "Common.ps1")
$home=Get-CodexHome;$factory=Get-FactoryHome;$override=Join-Path $home "AGENTS.override.md";$coreText=Read-Utf8 $override;$coreOn=$coreText -match 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'
$heartbeat=Join-Path $factory "state\watcher.heartbeat";$watcher="OFF"
if(Test-Path $heartbeat){try{$age=((Get-Date)-[DateTimeOffset]::Parse((Read-Utf8 $heartbeat))).TotalSeconds;$watcher=if($age -lt 180){"ON"}else{"STALE"}}catch{$watcher="STALE"}}
$router=Test-Path (Join-Path $factory "src\router\Route.ps1");$missionRuntime=Test-Path (Join-Path $factory "src\mission\Mission.ps1");$quotaGuard=Test-Path (Join-Path $factory "src\mission\QuotaCommon.ps1");$profile="unknown"
try{. (Join-Path $factory "src\router\Router.ps1");$profile=[string](Get-RouterConfig).profile}catch{}
$root=Get-ProjectRoot $Cwd;$registered="N/A";$missionState="none"
if($root){$registered=if(@(Get-ProjectRegistry|Where-Object{$_.root -eq $root}).Count){"ON"}else{"OFF"};$missionPath=Join-Path $root ".codex-smart-factory\mission.json";if(Test-Path -LiteralPath $missionPath -PathType Leaf){try{$m=Get-Content -Raw -LiteralPath $missionPath|ConvertFrom-Json;$missionState=[string]$m.status}catch{$missionState="error"}}}
$injected="UNKNOWN";$matchingRollout=$null;$files=@()
try{$files=Get-ChildItem -LiteralPath $home -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue|Where-Object{$_.FullName -notlike "$factory*"}|Sort-Object LastWriteTime -Descending|Select-Object -First 30}catch{}
foreach($f in $files){$slice=Read-FileSlices $f.FullName 1048576 262144;if(!$slice){continue};$cwdMatch=$false;foreach($c in Get-CwdsFromRollout $f.FullName){if($c -eq $Cwd -or ($root -and $c.StartsWith($root,[StringComparison]::OrdinalIgnoreCase))){$cwdMatch=$true;break}};if(!$cwdMatch){continue};$matchingRollout=$f.FullName;if($slice -match 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'){$injected="YES"}else{$injected="NO"};break}
$state="DEGRADED";if($coreOn -and $router -and $missionRuntime -and $quotaGuard -and $watcher -eq "ON" -and $injected -eq "YES"){$state="YES"}elseif($coreOn -and $injected -ne "YES"){$state="PENDING_RESTART"}
Write-Output ("BOOSTED: {0} | SmartFactory=1.1.0 | GlobalCore={1} | SessionInjected={2} | Router={3}({4}) | Mission={5}({6}) | QuotaGuard={7} | Watcher={8} | ProjectRegistry={9}" -f $state,$(if($coreOn){"ON"}else{"OFF"}),$injected,$(if($router){"ON"}else{"OFF"}),$profile,$(if($missionRuntime){"ON"}else{"OFF"}),$missionState,$(if($quotaGuard){"ON"}else{"OFF"}),$watcher,$registered)
Write-Output ("CODEX_HOME: "+$home);if($root){Write-Output ("Project: "+$root)};if($matchingRollout){Write-Output ("Evidence rollout: "+$matchingRollout)}
