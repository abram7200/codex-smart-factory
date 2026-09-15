. (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\Common.ps1")
. (Join-Path $PSScriptRoot "QuotaCommon.ps1")

function Get-MissionPolicy {
  $path=Join-Path (Get-FactoryHome) "state\mission-policy.json"
  if(!(Test-Path $path)){
    $default=[ordered]@{
      version=1
      five_hour_stop_remaining=15
      five_hour_heavy_min_remaining=25
      weekly_stop_remaining=10
      weekly_checkpoint_remaining=15
      checkpoint_interval_minutes=15
      fallback_session_checkpoint_minutes=210
      fallback_session_heavy_stop_minutes=240
      fallback_session_stop_minutes=260
      max_default_active_tasks=1
    }
    Write-Utf8 $path ($default|ConvertTo-Json -Depth 6)
  }
  Get-Content -Raw -LiteralPath $path|ConvertFrom-Json
}

function Get-MissionDir([string]$Root){Join-Path $Root ".codex-smart-factory"}
function Get-MissionStatePath([string]$Root){Join-Path (Get-MissionDir $Root) "mission.json"}

function Ensure-MissionDirectory([string]$Root){
  $dir=Get-MissionDir $Root
  New-Item -ItemType Directory -Force -Path (Join-Path $dir "tasks")|Out-Null
  try{Add-GitLocalExclude $Root ".codex-smart-factory/"}catch{}
  return $dir
}

function Read-MissionState([string]$Root){
  $path=Get-MissionStatePath $Root
  if(!(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{return (Get-Content -Raw -LiteralPath $path|ConvertFrom-Json)}catch{throw "Mission state is unreadable: $path"}
}

function Write-MissionJson([string]$Root,$State){
  $dir=Ensure-MissionDirectory $Root
  $State.updated_at=(Get-Date).ToString("o")
  $path=Join-Path $dir "mission.json"
  $tmp=$path+".tmp."+$PID
  Write-Utf8 $tmp ($State|ConvertTo-Json -Depth 20)
  Move-Item -LiteralPath $tmp -Destination $path -Force
}

function Markdown-Safe([object]$Value){
  if($null -eq $Value){return ""}
  (($Value.ToString() -replace '\|','\\|') -replace "`r?`n",'<br>')
}

function Join-List($Value){
  if($null -eq $Value){return ""}
  (@($Value)|Where-Object{$_}|ForEach-Object{[string]$_}) -join ", "
}

function Split-List([string]$Value){
  if([string]::IsNullOrWhiteSpace($Value)){return @()}
  @($Value -split '[,;]'|ForEach-Object{$_.Trim()}|Where-Object{$_})
}

function Get-Task($State,[string]$Id){
  @($State.tasks|Where-Object{$_.id -eq $Id}|Select-Object -First 1)[0]
}

function Get-NextTaskId($State){
  $max=0
  foreach($t in @($State.tasks)){
    if(([string]$t.id) -match '^T(\d+)$'){$n=[int]$Matches[1];if($n -gt $max){$max=$n}}
  }
  "T{0:D3}" -f ($max+1)
}

function Test-TaskDependenciesDone($State,$Task){
  foreach($dep in @($Task.depends_on)){
    if(!$dep){continue}
    $d=Get-Task $State ([string]$dep)
    if(!$d -or $d.status -ne "done"){return $false}
  }
  return $true
}

function Update-ReadyTasks($State){
  foreach($t in @($State.tasks)){
    if($t.status -eq "todo"){
      if(Test-TaskDependenciesDone $State $t){$t.status="ready"}
    }elseif($t.status -eq "blocked"){
      $kind=""
      if($t.PSObject.Properties["block_kind"]){$kind=[string]$t.block_kind}
      if($kind -eq "dependency" -and (Test-TaskDependenciesDone $State $t)){
        $t.status="ready"
        $t.block_kind=""
      }
    }
  }
}

function Get-GitSnapshot([string]$Root){
  $obj=[ordered]@{is_git=$false;branch=$null;status=@();diff_stat=@()}
  try{
    if(Test-Path -LiteralPath (Join-Path $Root ".git")){
      $obj.is_git=$true
      $obj.branch=((& git -C $Root branch --show-current 2>$null)|Out-String).Trim()
      $obj.status=@(& git -C $Root status --short 2>$null|Select-Object -First 100)
      $obj.diff_stat=@(& git -C $Root diff --stat 2>$null|Select-Object -First 100)
    }
  }catch{}
  [pscustomobject]$obj
}

function Append-Progress([string]$Root,[string]$Text){
  $path=Join-Path (Ensure-MissionDirectory $Root) "PROGRESS.md"
  if(!(Test-Path $path)){Write-Utf8 $path "# Progress`r`n`r`n"}
  Add-Content -Encoding UTF8 -LiteralPath $path -Value ("## "+(Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")+"`r`n`r`n"+$Text.Trim()+"`r`n")
}

function Append-Finding([string]$Root,[string]$Text){
  $path=Join-Path (Ensure-MissionDirectory $Root) "FINDINGS.md"
  if(!(Test-Path $path)){Write-Utf8 $path "# Findings and decisions`r`n`r`n"}
  Add-Content -Encoding UTF8 -LiteralPath $path -Value ("## "+(Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")+"`r`n`r`n"+$Text.Trim()+"`r`n")
}

function Get-QuotaDecision($State,[string]$RouteClass="balanced",[string]$Effort="medium",[switch]$Fresh){
  $policy=Get-MissionPolicy
  $q=Get-CodexQuotaSnapshot -Fresh:$Fresh
  $action="GO";$reason="quota healthy or unavailable with safe fallback"

  $five=$null;$week=$null
  if($q.five_hour){$five=[double]$q.five_hour.remaining_percent}
  if($q.weekly){$week=[double]$q.weekly.remaining_percent}

  if($null -ne $q.ordinary_usage_allowed -and $q.ordinary_usage_allowed -eq $false){$action="STOP";$reason="backend reports ordinary usage is not allowed"}
  elseif($q.rate_limit_reached_type){$action="STOP";$reason="backend reports rate limit reached: $($q.rate_limit_reached_type)"}
  elseif($null -ne $five -and $five -le [double]$policy.five_hour_stop_remaining){$action="STOP";$reason="5-hour remaining <= $($policy.five_hour_stop_remaining)%"}
  elseif($null -ne $week -and $week -le [double]$policy.weekly_stop_remaining){$action="STOP";$reason="weekly remaining <= $($policy.weekly_stop_remaining)%"}
  elseif(($RouteClass -in @("strong","frontier") -or $Effort -in @("high","xhigh","max")) -and $null -ne $five -and $five -lt [double]$policy.five_hour_heavy_min_remaining){$action="STOP";$reason="heavy task refused below $($policy.five_hour_heavy_min_remaining)% 5-hour remaining"}
  elseif(($null -ne $five -and $five -le [double]$policy.five_hour_heavy_min_remaining) -or ($null -ne $week -and $week -le [double]$policy.weekly_checkpoint_remaining)){$action="CHECKPOINT";$reason="quota pressure requires checkpoint before more work"}

  $minutes=0
  try{$minutes=((Get-Date)-[DateTimeOffset]::Parse([string]$State.session_started_at)).TotalMinutes}catch{}
  if(!$q.known -or $q.stale){
    if($minutes -ge [double]$policy.fallback_session_stop_minutes){$action="STOP";$reason="quota unavailable; fallback continuous-session safety stop"}
    elseif(($RouteClass -in @("strong","frontier") -or $Effort -in @("high","xhigh","max")) -and $minutes -ge [double]$policy.fallback_session_heavy_stop_minutes){$action="STOP";$reason="quota unavailable; do not start heavy task late in continuous session"}
    elseif($minutes -ge [double]$policy.fallback_session_checkpoint_minutes -and $action -eq "GO"){$action="CHECKPOINT";$reason="quota unavailable; fallback checkpoint cadence"}
  }

  [pscustomobject]@{action=$action;reason=$reason;quota=$q;session_minutes=[Math]::Round($minutes,1)}
}

function Get-NextReadyTask($State){
  Update-ReadyTasks $State
  @($State.tasks|Where-Object{$_.status -eq "ready"}|Select-Object -First 1)[0]
}

function Add-MarkdownSection([System.Collections.Generic.List[string]]$Lines,[string]$Heading,[string]$Body){
  $Lines.Add($Heading);$Lines.Add("")
  if([string]::IsNullOrWhiteSpace($Body)){$Lines.Add("(none)")}else{$Lines.Add($Body)}
  $Lines.Add("")
}

function Indent-Block([object[]]$Value){
  $items=@($Value|Where-Object{$null -ne $_})
  if(!$items.Count){return "    (none)"}
  (($items|ForEach-Object{"    "+([string]$_)}) -join "`r`n")
}

function Render-TaskCard([string]$Root,$Task){
  $dir=Join-Path (Ensure-MissionDirectory $Root) "tasks"
  $path=Join-Path $dir ($Task.id+".md")
  $lines=New-Object 'System.Collections.Generic.List[string]'
  $lines.Add("# $($Task.id) — $($Task.title)");$lines.Add("")
  $lines.Add("## State");$lines.Add("")
  $lines.Add("- Status: **$($Task.status)**")
  $lines.Add("- Relation: $($Task.relation)")
  $lines.Add("- Discovered from: $($Task.discovered_from)")
  $lines.Add("- Depends on: $(Join-List $Task.depends_on)")
  $lines.Add("- Related: $(Join-List $Task.related)")
  $lines.Add("- Risk: $($Task.risk)");$lines.Add("")
  Add-MarkdownSection $lines "## Why this task exists" ([string]$Task.why)
  $lines.Add("## Model plan");$lines.Add("")
  $lines.Add("- Best model: $($Task.best_model)")
  $lines.Add("- Reasoning effort: $($Task.effort)")
  $lines.Add("- Route class: $($Task.route_class)")
  $lines.Add("- Why this model: $($Task.model_reason)")
  $lines.Add("- Model actually used: $($Task.model_used)");$lines.Add("")
  Add-MarkdownSection $lines "## Scope / files" ([string]$Task.scope)
  Add-MarkdownSection $lines "## Acceptance" ([string]$Task.acceptance)
  Add-MarkdownSection $lines "## Verification" ([string]$Task.verify)
  Add-MarkdownSection $lines "## Last result / notes" ([string]$Task.notes)
  $lines.Add("## Timestamps");$lines.Add("")
  $lines.Add("- Created: $($Task.created_at)")
  $lines.Add("- Updated: $($Task.updated_at)")
  Write-Utf8 $path (($lines -join "`r`n").Trim()+"`r`n")
}

function Render-MissionDocs([string]$Root,$State,[string]$CheckpointReason="state-update"){
  $dir=Ensure-MissionDirectory $Root
  Update-ReadyTasks $State
  $q=$State.quota
  $five=if($q -and $q.five_hour){"{0:N1}%" -f [double]$q.five_hour.remaining_percent}else{"unknown"}
  $week=if($q -and $q.weekly){"{0:N1}%" -f [double]$q.weekly.remaining_percent}else{"unknown"}
  $mission=New-Object 'System.Collections.Generic.List[string]'
  $mission.Add("# Codex Smart Factory Mission");$mission.Add("")
  $mission.Add("- Mission ID: $($State.mission_id)")
  $mission.Add("- Status: **$($State.status)**")
  $mission.Add("- Current gate: **$($State.current_gate)**")
  $mission.Add("- Active task: $(if($State.active_task_id){$State.active_task_id}else{'none'})")
  $mission.Add("- Safe stop requested: **$($State.safe_stop_requested)**")
  $mission.Add("- Safe stop reason: $($State.safe_stop_reason)")
  $mission.Add("- 5h remaining: **$five**")
  $mission.Add("- Weekly remaining: **$week**");$mission.Add("")
  Add-MarkdownSection $mission "## Goal" ([string]$State.goal)
  Add-MarkdownSection $mission "## Success condition" ([string]$State.success)
  Add-MarkdownSection $mission "## Constraints / non-goals" ([string]$State.constraints)
  Add-MarkdownSection $mission "## Source plan" ([string]$State.source_plan)
  $mission.Add("## Workflow contract");$mission.Add("")
  $mission.Add("1. TASKS.md is the task DAG/checklist visible to the user.")
  $mission.Add("2. Each task has a detailed card under tasks/<ID>.md.")
  $mission.Add("3. Exactly one task is active by default; parallel work needs independent dependencies and write scopes.")
  $mission.Add("4. Run Mission preflight before each task and long/risky verification; STOP means checkpoint and stop.")
  $mission.Add("5. Register unexpected bugs/work before expanding scope; blocker/required discoveries become dependencies.")
  $mission.Add("6. RESUME-FROM-HERE.md is the deterministic recovery entrypoint.")
  $mission.Add("7. Resume recorded state instead of replanning unless fresh evidence invalidates the graph.")
  Write-Utf8 (Join-Path $dir "MISSION.md") (($mission -join "`r`n").Trim()+"`r`n")

  $lines=New-Object 'System.Collections.Generic.List[string]'
  $lines.Add("# Task graph and checklist");$lines.Add("")
  $lines.Add("| ID | Status | Task | Why | Depends on | Related | Relation | Discovered from | Best model | Effort | Why model | Model used | Scope | Verify | Updated |")
  $lines.Add("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
  foreach($task in @($State.tasks)){
    $lines.Add("| $(Markdown-Safe $task.id) | $(Markdown-Safe $task.status) | $(Markdown-Safe $task.title) | $(Markdown-Safe $task.why) | $(Markdown-Safe (Join-List $task.depends_on)) | $(Markdown-Safe (Join-List $task.related)) | $(Markdown-Safe $task.relation) | $(Markdown-Safe $task.discovered_from) | $(Markdown-Safe $task.best_model) | $(Markdown-Safe $task.effort) | $(Markdown-Safe $task.model_reason) | $(Markdown-Safe $task.model_used) | $(Markdown-Safe $task.scope) | $(Markdown-Safe $task.verify) | $(Markdown-Safe $task.updated_at) |")
    Render-TaskCard $Root $task
  }
  Write-Utf8 (Join-Path $dir "TASKS.md") (($lines -join "`r`n")+"`r`n")
  if(!(Test-Path (Join-Path $dir "PROGRESS.md"))){Write-Utf8 (Join-Path $dir "PROGRESS.md") "# Progress`r`n`r`n"}
  if(!(Test-Path (Join-Path $dir "FINDINGS.md"))){Write-Utf8 (Join-Path $dir "FINDINGS.md") "# Findings and decisions`r`n`r`n"}

  $git=Get-GitSnapshot $Root
  $active=if($State.active_task_id){Get-Task $State ([string]$State.active_task_id)}else{$null}
  $next=Get-NextReadyTask $State
  $nextAction=if($State.safe_stop_requested){"Do not start new work. Resume only after quota/session guard clears."}elseif($active -and $active.status -eq "doing"){"Continue $($active.id) from its task card, then verify and checkpoint."}elseif($next){"Start $($next.id) — $($next.title) after preflight."}else{"Reconcile blockers/completion; do not invent a new task without evidence."}
  $activeSummary=if($active){"$($active.id) — $($active.title) [$($active.status)]"}else{"none"}
  $missionScript=Join-Path (Get-FactoryHome) "src\mission\Mission.ps1"
  $resume=New-Object 'System.Collections.Generic.List[string]'
  $resume.Add("# RESUME FROM HERE");$resume.Add("")
  $resume.Add("> First recovery read after crash, context compaction, usage-limit pause, app close, or a new Codex session.");$resume.Add("")
  $resume.Add("## Mission");$resume.Add("")
  $resume.Add("- Mission ID: $($State.mission_id)")
  $resume.Add("- Mission status: **$($State.status)**")
  $resume.Add("- Gate: $($State.current_gate)")
  $resume.Add("- Checkpoint reason: $CheckpointReason")
  $resume.Add("- Checkpoint time: $($State.last_checkpoint_at)")
  $resume.Add("- Active task: **$activeSummary**")
  $resume.Add("- Safe stop requested: **$($State.safe_stop_requested)**")
  $resume.Add("- Safe stop reason: $($State.safe_stop_reason)");$resume.Add("")
  $resume.Add("## Quota snapshot");$resume.Add("")
  $resume.Add("- Source: $(if($q){$q.source}else{'unavailable'})")
  $resume.Add("- 5h remaining: **$five**")
  $resume.Add("- Weekly remaining: **$week**")
  $resume.Add("- Backend ordinary usage allowed: $(if($q){$q.ordinary_usage_allowed}else{$null})")
  $resume.Add("- Reached type: $(if($q){$q.rate_limit_reached_type}else{$null})");$resume.Add("")
  $resume.Add("## Exact next action");$resume.Add("");$resume.Add("**$nextAction**");$resume.Add("")
  $resume.Add("## Recovery protocol");$resume.Add("")
  $resume.Add("1. Read this file first.")
  $resume.Add("2. Read MISSION.md and TASKS.md.")
  $resume.Add("3. Read only the active/next task card under tasks/.")
  $resume.Add("4. Read the tail of PROGRESS.md and FINDINGS.md; do not replay the whole history unless necessary.")
  $resume.Add("5. Reconcile the Git snapshot below with the live working tree.")
  $resume.Add("6. Run Mission resume, then Mission preflight before heavy work.")
  $resume.Add("7. Continue the recorded task; do not restart planning unless fresh evidence invalidates dependencies or acceptance criteria.");$resume.Add("")
  $resume.Add("Resume command:");$resume.Add("")
  $resume.Add("    & `"$missionScript`" resume -Root `"$Root`");$resume.Add("")
  $resume.Add("## Git snapshot");$resume.Add("")
  $resume.Add("- Branch: $($git.branch)");$resume.Add("")
  $resume.Add("### git status --short");$resume.Add("");$resume.Add((Indent-Block $git.status));$resume.Add("")
  $resume.Add("### git diff --stat");$resume.Add("");$resume.Add((Indent-Block $git.diff_stat));$resume.Add("")
  Add-MarkdownSection $resume "## Mission goal" ([string]$State.goal)
  Add-MarkdownSection $resume "## Success condition" ([string]$State.success)
  Write-Utf8 (Join-Path $dir "RESUME-FROM-HERE.md") (($resume -join "`r`n").Trim()+"`r`n")

  $stopPath=Join-Path $dir "SAFE-STOP.md"
  if($State.safe_stop_requested){
    $stopLines=@("# SAFE STOP REQUESTED","","Do not start new implementation, routed workers, broad verification, migration, installation, or destructive work until Mission resume/preflight clears this state.","","Reason: $($State.safe_stop_reason)","Checkpoint: $($State.last_checkpoint_at)","Resume file: RESUME-FROM-HERE.md")
    Write-Utf8 $stopPath (($stopLines -join "`r`n")+"`r`n")
  }elseif(Test-Path $stopPath){Remove-Item -LiteralPath $stopPath -Force -ErrorAction SilentlyContinue}
}

function Save-MissionState([string]$Root,$State,[string]$CheckpointReason="state-update"){
  Write-MissionJson $Root $State
  Render-MissionDocs $Root $State $CheckpointReason
  Write-MissionJson $Root $State
}

function Validate-MissionPlan($State){
  $errors=New-Object 'System.Collections.Generic.List[string]';$ids=@{}
  foreach($t in @($State.tasks)){
    if(!$t.id){$errors.Add("task missing id");continue}
    if($ids.ContainsKey([string]$t.id)){$errors.Add("duplicate task id: $($t.id)")}else{$ids[[string]$t.id]=$t}
    if([string]::IsNullOrWhiteSpace([string]$t.title)){$errors.Add("$($t.id): missing task title")}
    if([string]::IsNullOrWhiteSpace([string]$t.why)){$errors.Add("$($t.id): missing why")}
    if([string]::IsNullOrWhiteSpace([string]$t.verify) -and $t.status -notin @("deferred","out-of-scope")){$errors.Add("$($t.id): missing verification")}
    if([string]::IsNullOrWhiteSpace([string]$t.best_model) -and $t.status -notin @("deferred","out-of-scope")){$errors.Add("$($t.id): missing model route")}
  }
  foreach($t in @($State.tasks)){
    foreach($d in @($t.depends_on)){
      if(!$d){continue}
      if($d -eq $t.id){$errors.Add("$($t.id): self dependency")}
      elseif(!$ids.ContainsKey([string]$d)){$errors.Add("$($t.id): missing dependency $d")}
    }
  }
  $doing=@($State.tasks|Where-Object{$_.status -eq "doing"});if($doing.Count -gt 1){$errors.Add("multiple doing tasks without explicit parallel controller")}
  $active=@($State.tasks|Where-Object{$_.status -notin @("deferred","out-of-scope")});$ind=@{};$edges=@{}
  foreach($t in $active){$ind[$t.id]=0;$edges[$t.id]=New-Object 'Collections.Generic.List[string]'}
  foreach($t in $active){foreach($d in @($t.depends_on)){if($ind.ContainsKey([string]$d)){$ind[$t.id]=[int]$ind[$t.id]+1;$edges[[string]$d].Add([string]$t.id)}}}
  $q=New-Object 'Collections.Generic.Queue[string]';foreach($k in @($ind.Keys)){if([int]$ind[$k] -eq 0){$q.Enqueue([string]$k)}}
  $processed=0
  while($q.Count){$x=$q.Dequeue();$processed++;foreach($n in $edges[$x]){$ind[$n]=[int]$ind[$n]-1;if([int]$ind[$n] -eq 0){$q.Enqueue([string]$n)}}}
  if($processed -lt $active.Count){$errors.Add("task dependency graph contains a cycle")}
  [pscustomobject]@{valid=($errors.Count -eq 0);errors=@($errors)}
}

function Invoke-MissionCheckpoint([string]$Root,$State,[string]$Reason="checkpoint",[switch]$FreshQuota){
  $qd=Get-QuotaDecision $State "balanced" "medium" -Fresh:$FreshQuota
  $State.quota=$qd.quota;$State.last_checkpoint_at=(Get-Date).ToString("o")
  if($qd.action -eq "STOP"){$State.safe_stop_requested=$true;$State.safe_stop_reason=$qd.reason;if($State.status -ne "done"){$State.status="paused";$State.current_gate="pause"}}
  Save-MissionState $Root $State $Reason
  Append-Progress $Root ("- Checkpoint: **$Reason**`r`n- Quota action: **$($qd.action)** — $($qd.reason)")
  return $qd
}
