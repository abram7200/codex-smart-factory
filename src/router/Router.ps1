. (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\Common.ps1")

function Get-RouterConfig {
  $factory = Get-FactoryHome
  $state = Join-Path $factory "state"
  New-Item -ItemType Directory -Force -Path $state | Out-Null
  $path = Join-Path $state "router.json"
  if (!(Test-Path $path)) {
    $default = [ordered]@{
      version=1
      profile="balanced"
      never_auto_ultra=$true
      profiles=[ordered]@{
        "token-saver"=[ordered]@{balanced=3;strong=7;frontier=11}
        "balanced"=[ordered]@{balanced=2;strong=5;frontier=8}
        "max-quality"=[ordered]@{balanced=1;strong=3;frontier=6}
      }
    }
    Write-Utf8 $path ($default | ConvertTo-Json -Depth 8)
  }
  Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}

function Set-RouterProfile([string]$Profile) {
  if ($Profile -notin @("token-saver","balanced","max-quality")) { throw "Invalid profile: $Profile" }
  $factory = Get-FactoryHome
  $path = Join-Path $factory "state\router.json"
  $cfg = Get-RouterConfig
  $cfg.profile = $Profile
  Write-Utf8 $path ($cfg | ConvertTo-Json -Depth 8)
  $path
}

function Get-ModelCatalog {
  $cache = Join-Path (Get-CodexHome) "models_cache.json"
  if (Test-Path $cache) {
    try {
      $j = Get-Content -Raw -LiteralPath $cache | ConvertFrom-Json
      $modelsProp=$j.PSObject.Properties["models"]
      if ($modelsProp -and @($modelsProp.Value).Count) { return @($modelsProp.Value) }
      if ($j -is [Array] -and @($j).Count) { return @($j) }
    } catch {}
  }

  $codex = Get-Command codex -ErrorAction SilentlyContinue
  if (!$codex) { $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue }

  if ($codex) {
    try {
      $raw = & $codex.Source debug models --bundled 2>$null | Out-String
      $j = $raw | ConvertFrom-Json
      $modelsProp=$j.PSObject.Properties["models"]
      if ($modelsProp -and @($modelsProp.Value).Count) { return @($modelsProp.Value) }
    } catch {}
  }

  if ($codex) {
    try {
      $raw = & $codex.Source debug models 2>$null | Out-String
      $j = $raw | ConvertFrom-Json
      $modelsProp=$j.PSObject.Properties["models"]
      if ($modelsProp -and @($modelsProp.Value).Count) { return @($modelsProp.Value) }
    } catch {}
  }
  @()
}

function Get-OptionalProperty($Object,[string]$Name) {
  if($null -eq $Object){ return $null }
  $prop=$Object.PSObject.Properties[$Name]
  if($prop){ return $prop.Value }
  return $null
}

function Normalize-Catalog($RawCatalog) {
  $out = @()
  foreach ($m in @($RawCatalog)) {
    $slugValue=Get-OptionalProperty $m "slug"
    $slug=[string]$slugValue
    if(!$slug){ continue }

    $visibility=[string](Get-OptionalProperty $m "visibility")
    if($visibility -and $visibility.ToLowerInvariant() -in @("hide","hidden","none")){ continue }
    if($slug -eq "codex-auto-review"){ continue }

    $levels=@()
    foreach($field in @("supported_reasoning_levels","supported_reasoning_efforts")){
      $v=Get-OptionalProperty $m $field
      if($null -eq $v){ continue }
      foreach($x in @($v)){
        if($x -is [string]){
          $levels += [string]$x
        }else{
          $effort=Get-OptionalProperty $x "effort"
          if($effort){ $levels += [string]$effort }
        }
      }
    }

    $priorityValue=Get-OptionalProperty $m "priority"
    $priority=999
    if($null -ne $priorityValue){ $priority=[int]$priorityValue }

    $out += [pscustomobject]@{
      slug=$slug
      display_name=[string](Get-OptionalProperty $m "display_name")
      priority=$priority
      visibility=$visibility
      efforts=@($levels | Select-Object -Unique)
      default_effort=[string](Get-OptionalProperty $m "default_reasoning_level")
      context_window=(Get-OptionalProperty $m "context_window")
    }
  }
  @($out | Sort-Object priority,slug)
}

function Get-TaskFeatures([string]$Task) {
  $t = ($Task+"").ToLowerInvariant()
  $score = 0
  $signals = New-Object 'System.Collections.Generic.List[string]'

  $risk = @(
    "security","auth","authentication","authorization","permission","privacy","credential","secret",
    "payment","billing","financial","migration","production","deploy","deployment","rollback",
    "data loss","corruption","race condition","deadlock","concurrency","distributed","architecture",
    "incident","compliance","legal"
  )
  foreach ($k in $risk) { if ($t.Contains($k)) {$score += 2; $signals.Add("risk:$k")} }
  if($t -match 'risk:\s*critical'){ $score += 4; $signals.Add("risk-level:critical") }
  elseif($t -match 'risk:\s*high'){ $score += 2; $signals.Add("risk-level:high") }

  $complex = @(
    "root cause","debug","refactor","cross-module","cross module","multi-file","multiple files",
    "performance","memory leak","integration","redesign","state machine","protocol","compatibility",
    "upgrade","dependency conflict","flaky","intermittent"
  )
  foreach ($k in $complex) { if ($t.Contains($k)) {$score += 1; $signals.Add("complex:$k")} }

  $simple = @(
    "typo","format","formatting","rename","readme","documentation","comment","list files",
    "find file","status","version bump","one line","one-line"
  )
  foreach ($k in $simple) { if ($t.Contains($k)) {$score -= 2; $signals.Add("simple:$k")} }

  if ($Task.Length -gt 1200) {$score += 1; $signals.Add("long-spec")}
  if ($Task.Length -lt 100 -and $score -le 0) {$score -= 1; $signals.Add("short-low-risk")}

  [pscustomobject]@{
    score=$score
    signals=@($signals)
    write=($t -match '\b(fix|implement|add|change|edit|refactor|migrate|upgrade|remove|delete|create|build)\b')
    visual=($t -match '\b(image|screenshot|photo|figma|video)\b')
  }
}

function Get-RouteClass([int]$Score,$Config) {
  $prop = $Config.profiles.PSObject.Properties[[string]$Config.profile]
  $th = if ($prop) {$prop.Value} else {$Config.profiles.balanced}
  if ($Score -ge [int]$th.frontier) { return "frontier" }
  if ($Score -ge [int]$th.strong) { return "strong" }
  if ($Score -ge [int]$th.balanced) { return "balanced" }
  "economy"
}

function Select-Model([string]$Class,$Catalog) {
  $prefs = switch ($Class) {
    "frontier" { @("gpt-6-astra","gpt-5.6-sol","gpt-5.6-terra","gpt-5.6-luna") }
    "strong"   { @("gpt-5.6-sol","gpt-6-astra","gpt-5.6-terra","gpt-5.6-luna") }
    "balanced" { @("gpt-5.6-terra","gpt-5.6-sol","gpt-5.6-luna","gpt-6-astra") }
    default    { @("gpt-5.6-luna","gpt-5.6-terra","gpt-5.6-sol","gpt-6-astra") }
  }
  foreach ($slug in $prefs) {
    $m = @($Catalog | Where-Object {$_.slug -eq $slug} | Select-Object -First 1)
    if ($m.Count) { return $m[0] }
  }
  $patterns = switch ($Class) {
    "frontier" { @("astra","frontier") }
    "strong" { @("sol","flagship") }
    "balanced" { @("terra","balanced") }
    default { @("luna","mini","nano","spark") }
  }
  foreach ($pat in $patterns) {
    $m = @($Catalog | Where-Object {(($_.slug+" "+$_.display_name) -match [regex]::Escape($pat))} | Select-Object -First 1)
    if ($m.Count) { return $m[0] }
  }
  $null
}

function Get-RequestedEffort([int]$Score) {
  if ($Score -ge 9) { return "max" }
  if ($Score -ge 6) { return "xhigh" }
  if ($Score -ge 4) { return "high" }
  if ($Score -ge 1) { return "medium" }
  "low"
}

function Clamp-Effort([string]$Requested,$Model) {
  $order = @("none","minimal","low","medium","high","xhigh","max","ultra")
  $levels = @($Model.efforts | Where-Object {$_ -ne "ultra"})
  if (!$levels.Count) {
    if ($Model.default_effort -and $Model.default_effort -ne "ultra") { return [string]$Model.default_effort }
    return "medium"
  }
  if ($levels -contains $Requested) { return $Requested }
  $ri = [Array]::IndexOf($order,$Requested)
  if ($ri -lt 0) {$ri=[Array]::IndexOf($order,"medium")}
  $best=$null; $dist=999; $bestIndex=999
  foreach ($l in $levels) {
    $i=[Array]::IndexOf($order,[string]$l)
    if ($i -lt 0) {continue}
    $d=[Math]::Abs($i-$ri)
    if ($d -lt $dist -or ($d -eq $dist -and $i -lt $bestIndex)) {
      $best=[string]$l; $dist=$d; $bestIndex=$i
    }
  }
  if ($best) { return $best }
  [string]($levels | Select-Object -First 1)
}

function Write-RouteLedger($Decision) {
  try {
    $path = Join-Path (Get-FactoryHome) "state\routing-ledger.jsonl"
    $safe = [ordered]@{
      time=(Get-Date).ToString("o")
      task_hash=$Decision.task_hash
      profile=$Decision.profile
      score=$Decision.score
      class=$Decision.route_class
      model=$Decision.model
      effort=$Decision.effort
      action=$Decision.action
    }
    ($safe | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $path
  } catch {}
}

function Resolve-Route([string]$Task,[string]$CurrentModel="") {
  $cfg = Get-RouterConfig
  $catalog = Normalize-Catalog (Get-ModelCatalog)
  $features = Get-TaskFeatures $Task
  $class = Get-RouteClass ([int]$features.score) $cfg
  $model = Select-Model $class $catalog
  $requested = Get-RequestedEffort ([int]$features.score)
  $effort = if ($model) {Clamp-Effort $requested $model} else {$requested}

  $action = "local"
  $signalText=if(@($features.signals).Count){@($features.signals) -join ", "}else{"no high-risk/complexity signals"}
  $modelText=if($model){[string]$model.slug}else{"Codex-default"}
  $reason = "route=$class from score=$($features.score) ($signalText); selected $modelText as the first available live-catalog match; stay local because routing overhead likely exceeds benefit"
  if (!$model) {
    $reason = "route=$class from score=$($features.score) ($signalText); no verified catalog candidate, so fail-open to the current lead"
  } elseif ($features.visual) {
    $reason = "route=$class suggests $modelText/$effort, but the task appears visual/attachment-dependent; keep the live task unless exact inputs can be passed"
  } elseif ($CurrentModel -and $CurrentModel -eq $model.slug) {
    $reason = "route=$class from score=$($features.score) ($signalText); current model already matches recommended $modelText/$effort"
  } elseif ([int]$features.score -ge 2) {
    $action = "worker-recommended"
    $reason = "route=$class from score=$($features.score) ($signalText); $modelText/$effort is the best available catalog match and the task is substantial enough to justify a bounded worker"
  }

  $d = [pscustomobject]@{
    profile=[string]$cfg.profile
    task_hash=(Get-ShortHash $Task)
    score=[int]$features.score
    signals=@($features.signals)
    route_class=$class
    model=if($model){[string]$model.slug}else{$null}
    effort=$effort
    action=$action
    reason=$reason
    write_task=[bool]$features.write
    catalog_count=@($catalog).Count
  }
  Write-RouteLedger $d
  $d
}
