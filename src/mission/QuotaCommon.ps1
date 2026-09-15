. (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\Common.ps1")

function Get-QuotaCachePath {
  Join-Path (Get-FactoryHome) "state\quota-cache.json"
}

function Read-JsonLineWithTimeout($Reader,[DateTime]$Deadline){
  while((Get-Date) -lt $Deadline){
    $remaining=[Math]::Max(50,[int](($Deadline-(Get-Date)).TotalMilliseconds))
    $task=$Reader.ReadLineAsync()
    if(!$task.Wait($remaining)){throw "Timed out waiting for codex app-server response."}
    $line=$task.Result
    if($null -eq $line){throw "codex app-server closed stdout before the response arrived."}
    if([string]::IsNullOrWhiteSpace($line)){continue}
    try{return ($line|ConvertFrom-Json)}catch{continue}
  }
  throw "Timed out waiting for codex app-server response."
}

function Invoke-CodexAppServerRequest([string]$Method,$Params=$null,[int]$TimeoutSeconds=10){
  $codex=Get-Command codex -ErrorAction SilentlyContinue
  if(!$codex){$codex=Get-Command codex.cmd -ErrorAction SilentlyContinue}
  if(!$codex){throw "Codex CLI not found in PATH."}

  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=$codex.Source
  $psi.Arguments="app-server --listen stdio://"
  $psi.UseShellExecute=$false
  $psi.RedirectStandardInput=$true
  $psi.RedirectStandardOutput=$true
  $psi.CreateNoWindow=$true
  try{$psi.EnvironmentVariables["RUST_LOG"]="error"}catch{}

  $p=New-Object Diagnostics.Process
  $p.StartInfo=$psi
  if(!$p.Start()){throw "Failed to start codex app-server."}
  $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
  try{
    $init=[ordered]@{
      method="initialize"
      id=1
      params=[ordered]@{
        clientInfo=[ordered]@{
          name="codex_smart_factory"
          title="Codex Smart Factory"
          version="1.1.0"
        }
        capabilities=[ordered]@{
          optOutNotificationMethods=@(
            "thread/started","item/agentMessage/delta","thread/tokenUsage/updated",
            "account/rateLimits/updated","remoteControl/status/changed"
          )
        }
      }
    }
    $p.StandardInput.WriteLine(($init|ConvertTo-Json -Compress -Depth 8));$p.StandardInput.Flush()
    while($true){
      $msg=Read-JsonLineWithTimeout $p.StandardOutput $deadline
      if($msg.id -eq 1){
        if($msg.error){throw ("app-server initialize failed: "+($msg.error|ConvertTo-Json -Compress))}
        break
      }
    }

    $p.StandardInput.WriteLine('{"method":"initialized"}');$p.StandardInput.Flush()
    $req=[ordered]@{method=$Method;id=2}
    if($null -ne $Params){$req.params=$Params}
    $p.StandardInput.WriteLine(($req|ConvertTo-Json -Compress -Depth 12));$p.StandardInput.Flush()
    while($true){
      $msg=Read-JsonLineWithTimeout $p.StandardOutput $deadline
      if($msg.id -eq 2){
        if($msg.error){throw ("app-server request failed: "+($msg.error|ConvertTo-Json -Compress))}
        return $msg
      }
    }
  }finally{
    try{$p.StandardInput.Close()}catch{}
    try{if(!$p.HasExited){$p.Kill()}}catch{}
    try{$p.Dispose()}catch{}
  }
}

function Convert-RateWindow($Window){
  if(!$Window){return $null}
  $used=if($null -ne $Window.usedPercent){[double]$Window.usedPercent}else{$null}
  if($null -eq $used){return $null}
  $duration=if($null -ne $Window.windowDurationMins){[int64]$Window.windowDurationMins}else{$null}
  $reset=if($null -ne $Window.resetsAt){[int64]$Window.resetsAt}else{$null}
  [pscustomobject]@{
    used_percent=[Math]::Max(0,[Math]::Min(100,$used))
    remaining_percent=[Math]::Max(0,[Math]::Min(100,100-$used))
    window_minutes=$duration
    resets_at=$reset
  }
}

function Select-CodexRateSnapshot($Result){
  if(!$Result){return $null}
  if($Result.rateLimitsByLimitId){
    $prop=$Result.rateLimitsByLimitId.PSObject.Properties["codex"]
    if($prop -and $prop.Value){return $prop.Value}
  }
  if($Result.rateLimits){return $Result.rateLimits}
  return $null
}

function Convert-RateLimitsResult($Result,[string]$Source="app-server"){
  $snap=Select-CodexRateSnapshot $Result
  $windows=@()
  if($snap){
    if($snap.primary){$windows+=,(Convert-RateWindow $snap.primary)}
    if($snap.secondary){$windows+=,(Convert-RateWindow $snap.secondary)}
  }
  $windows=@($windows|Where-Object{$_})
  $five=@($windows|Where-Object{$_.window_minutes -eq 300}|Select-Object -First 1)
  $week=@($windows|Where-Object{$_.window_minutes -eq 10080}|Select-Object -First 1)
  $ordinary=$null
  if($Result.PSObject.Properties["ordinaryUsageAllowed"]){$ordinary=$Result.ordinaryUsageAllowed}
  $reached=if($snap -and $snap.rateLimitReachedType){[string]$snap.rateLimitReachedType}else{$null}

  [pscustomobject]@{
    captured_at=(Get-Date).ToString("o")
    known=($five.Count -gt 0 -or $week.Count -gt 0)
    source=$Source
    stale=$false
    ordinary_usage_allowed=$ordinary
    rate_limit_reached_type=$reached
    five_hour=if($five.Count){$five[0]}else{$null}
    weekly=if($week.Count){$week[0]}else{$null}
    other_windows=@($windows|Where-Object{$_.window_minutes -notin @(300,10080)})
  }
}

function Save-QuotaCache($Snapshot){try{Write-Utf8 (Get-QuotaCachePath) ($Snapshot|ConvertTo-Json -Depth 10)}catch{}}

function Get-CodexQuotaSnapshot([switch]$Fresh,[int]$CacheSeconds=120){
  if($env:CSF_QUOTA_MOCK_JSON){
    try{$mock=$env:CSF_QUOTA_MOCK_JSON|ConvertFrom-Json;if($mock.result){return (Convert-RateLimitsResult $mock.result "mock")};return (Convert-RateLimitsResult $mock "mock")}catch{}
  }
  $cache=Get-QuotaCachePath
  if(!$Fresh -and (Test-Path $cache)){
    try{$c=Get-Content -Raw -LiteralPath $cache|ConvertFrom-Json;$age=((Get-Date)-[DateTimeOffset]::Parse([string]$c.captured_at)).TotalSeconds;if($age -le $CacheSeconds){return $c}}catch{}
  }
  try{$rpc=Invoke-CodexAppServerRequest "account/rateLimits/read" $null 12;$q=Convert-RateLimitsResult $rpc.result "app-server";Save-QuotaCache $q;return $q}catch{Write-FactoryLog ("Quota read failed: "+$_.Exception.Message)}
  if(Test-Path $cache){try{$c=Get-Content -Raw -LiteralPath $cache|ConvertFrom-Json;$c.stale=$true;$c.source="stale-cache";return $c}catch{}}
  [pscustomobject]@{captured_at=(Get-Date).ToString("o");known=$false;source="unavailable";stale=$true;ordinary_usage_allowed=$null;rate_limit_reached_type=$null;five_hour=$null;weekly=$null}
}
