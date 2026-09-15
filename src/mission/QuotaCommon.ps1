. (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\Common.ps1")

function Get-QuotaCachePath {
  Join-Path (Get-FactoryHome) "state\quota-cache.json"
}

function Get-QuotaProperty($Object,[string]$Name){
  if($null -eq $Object){return $null}
  $prop=$Object.PSObject.Properties[$Name]
  if($prop){return $prop.Value}
  return $null
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
      $msgId=Get-QuotaProperty $msg "id"
      if($msgId -eq 1){
        $err=Get-QuotaProperty $msg "error"
        if($err){throw ("app-server initialize failed: "+($err|ConvertTo-Json -Compress))}
        break
      }
    }

    $p.StandardInput.WriteLine('{"method":"initialized"}');$p.StandardInput.Flush()
    $req=[ordered]@{method=$Method;id=2}
    if($null -ne $Params){$req.params=$Params}
    $p.StandardInput.WriteLine(($req|ConvertTo-Json -Compress -Depth 12));$p.StandardInput.Flush()
    while($true){
      $msg=Read-JsonLineWithTimeout $p.StandardOutput $deadline
      $msgId=Get-QuotaProperty $msg "id"
      if($msgId -eq 2){
        $err=Get-QuotaProperty $msg "error"
        if($err){throw ("app-server request failed: "+($err|ConvertTo-Json -Compress))}
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
  $usedValue=Get-QuotaProperty $Window "usedPercent"
  if($null -eq $usedValue){return $null}
  $used=[double]$usedValue

  $durationValue=Get-QuotaProperty $Window "windowDurationMins"
  $duration=$null
  if($null -ne $durationValue){$duration=[int64]$durationValue}

  $resetValue=Get-QuotaProperty $Window "resetsAt"
  $reset=$null
  if($null -ne $resetValue){$reset=[int64]$resetValue}

  [pscustomobject]@{
    used_percent=[Math]::Max(0,[Math]::Min(100,$used))
    remaining_percent=[Math]::Max(0,[Math]::Min(100,100-$used))
    window_minutes=$duration
    resets_at=$reset
  }
}

function Select-CodexRateSnapshot($Result){
  if(!$Result){return $null}

  $byLimit=Get-QuotaProperty $Result "rateLimitsByLimitId"
  if($byLimit){
    $prop=$byLimit.PSObject.Properties["codex"]
    if($prop -and $prop.Value){return $prop.Value}
  }

  $limits=Get-QuotaProperty $Result "rateLimits"
  if($limits){return $limits}
  return $null
}

function Convert-RateLimitsResult($Result,[string]$Source="app-server"){
  $snap=Select-CodexRateSnapshot $Result
  $windows=@()
  if($snap){
    $primary=Get-QuotaProperty $snap "primary"
    $secondary=Get-QuotaProperty $snap "secondary"
    if($primary){$windows+=,(Convert-RateWindow $primary)}
    if($secondary){$windows+=,(Convert-RateWindow $secondary)}
  }
  $windows=@($windows|Where-Object{$_})
  $five=@($windows|Where-Object{$_.window_minutes -eq 300}|Select-Object -First 1)
  $week=@($windows|Where-Object{$_.window_minutes -eq 10080}|Select-Object -First 1)

  $ordinary=Get-QuotaProperty $Result "ordinaryUsageAllowed"
  $reached=$null
  if($snap){
    $reachedValue=Get-QuotaProperty $snap "rateLimitReachedType"
    if($reachedValue){$reached=[string]$reachedValue}
  }

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

function Save-QuotaCache($Snapshot){
  try{Write-Utf8 (Get-QuotaCachePath) ($Snapshot|ConvertTo-Json -Depth 10)}catch{}
}

function Get-CodexQuotaSnapshot([switch]$Fresh,[int]$CacheSeconds=120){
  if($env:CSF_QUOTA_MOCK_JSON){
    try{
      $mock=$env:CSF_QUOTA_MOCK_JSON|ConvertFrom-Json
      $mockResult=Get-QuotaProperty $mock "result"
      if($mockResult){return (Convert-RateLimitsResult $mockResult "mock")}
      return (Convert-RateLimitsResult $mock "mock")
    }catch{
      Write-FactoryLog ("Quota mock parse failed: "+$_.Exception.Message)
    }
  }

  $cache=Get-QuotaCachePath
  if(!$Fresh -and (Test-Path $cache)){
    try{
      $c=Get-Content -Raw -LiteralPath $cache|ConvertFrom-Json
      $captured=Get-QuotaProperty $c "captured_at"
      if($captured){
        $age=((Get-Date)-[DateTimeOffset]::Parse([string]$captured)).TotalSeconds
        if($age -le $CacheSeconds){return $c}
      }
    }catch{}
  }

  try{
    $rpc=Invoke-CodexAppServerRequest "account/rateLimits/read" $null 12
    $result=Get-QuotaProperty $rpc "result"
    if(!$result){throw "app-server response did not include result."}
    $q=Convert-RateLimitsResult $result "app-server"
    Save-QuotaCache $q
    return $q
  }catch{
    Write-FactoryLog ("Quota read failed: "+$_.Exception.Message)
  }

  if(Test-Path $cache){
    try{
      $c=Get-Content -Raw -LiteralPath $cache|ConvertFrom-Json
      $staleProp=$c.PSObject.Properties["stale"]
      if($staleProp){$c.stale=$true}else{$c|Add-Member -NotePropertyName stale -NotePropertyValue $true}
      $sourceProp=$c.PSObject.Properties["source"]
      if($sourceProp){$c.source="stale-cache"}else{$c|Add-Member -NotePropertyName source -NotePropertyValue "stale-cache"}
      return $c
    }catch{}
  }

  [pscustomobject]@{
    captured_at=(Get-Date).ToString("o")
    known=$false
    source="unavailable"
    stale=$true
    ordinary_usage_allowed=$null
    rate_limit_reached_type=$null
    five_hour=$null
    weekly=$null
  }
}
