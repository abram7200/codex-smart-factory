. (Join-Path (Split-Path -Parent $PSScriptRoot) "runtime\Common.ps1")
. (Join-Path $PSScriptRoot "QuotaCommon.ps1")

function Get-MissionPolicy {
  $path=Join-Path (Get-FactoryHome) "state\mission-policy.json"
  if(!(Test-Path -LiteralPath $path)){
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

function Get-MissionDir([string]$Root){
  Join-Path $Root ".codex-smart-factory"
}

function Get-MissionStatePath([string]$Root){
  Join-Path (Get-MissionDir $Root) "mission.json"
}

function Ensure-MissionDirectory([string]$Root){
  $dir=Get-MissionDir $Root
  New-Item -ItemType Directory -Force -Path (Join-Path $dir "tasks")|Out-Null
  try{
    Add-GitLocalExclude $Root ".codex-smart-factory/"
  }catch{}
  return $dir
}

function Read-MissionState([string]$Root){
  $path=Get-MissionStatePath $Root
  if(!(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    return (Get-Content -Raw -LiteralPath $path|ConvertFrom-Json)
  }catch{
    throw ("Mission state is unreadable: {0}" -f $path)
  }
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
  $text=$Value.ToString()
  $text=$text -replace '\|','\\|'
  $text=$text -replace "`r?`n",'<br>'
  return $text
}

function Join-List($Value){
  if($null -eq $Value){return ""}
  return ((@($Value)|Where-Object{$_}|ForEach-Object{[string]$_}) -join ", ")
}

function Split-List([string]$Value){
  if([string]::IsNullOrWhiteSpace($Value)){return @()}
  return @($Value -split '[,;]'|ForEach-Object{$_.Trim()}|Where-Object{$_})
}

function Get-Task($State,[string]$Id){
  $items=@($State.tasks|Where-Object{$_.id -eq $Id}|Select-Object -First 1)
  if($items.Count){return $items[0]}
  return $null
}

function Get-NextTaskId($State){
  $max=0
  foreach($t in @($State.tasks)){
    $taskId=[string]$t.id
    if($taskId -match '^T(\d+)$'){
      $n=[int]$Matches[1]
      if($n -gt $max){$max=$n}
    }
  }
  return ("T{0:D3}" -f ($max+1))
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
      if(Test-TaskDependenciesDone $State $t){
        $t.status="ready"
      }
    }elseif($t.status -eq "blocked"){
      $kind=""
      if($t.PSObject.Properties["block_kind"]){
        $kind=[string]$t.block_kind
      }
      if($kind -eq "dependency"){
        if(Test-TaskDependenciesDone $State $t){
          $t.status="ready"
          $t.block_kind=""
        }
      }
    }
  }
}

function Get-GitSnapshot([string]$Root){
  $obj=[ordered]@{
    is_git=$false
    branch=$null
    status=@()
    diff_stat=@()
  }
  try{
    if(Test-Path -LiteralPath (Join-Path $Root ".git")){
      $obj.is_git=$true
      $branchOutput=& git -C $Root branch --show-current 2>$null
      $obj.branch=($branchOutput|Out-String).Trim()
      $obj.status=@(& git -C $Root status --short 2>$null|Select-Object -First 100)
      $obj.diff_stat=@(& git -C $Root diff --stat 2>$null|Select-Object -First 100)
    }
  }catch{}
  return [pscustomobject]$obj
}

function Append-Progress([string]$Root,[string]$Text){
  $path=Join-Path (Ensure-MissionDirectory $Root) "PROGRESS.md"
  if(!(Test-Path -LiteralPath $path)){
    Write-Utf8 $path "# Progress`r`n`r`n"
  }
  $stamp=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")
  $entry="## {0}`r`n`r`n{1}`r`n" -f $stamp,$Text.Trim()
  Add-Content -Encoding UTF8 -LiteralPath $path -Value $entry
}

function Append-Finding([string]$Root,[string]$Text){
  $path=Join-Path (Ensure-MissionDirectory $Root) "FINDINGS.md"
  if(!(Test-Path -LiteralPath $path)){
    Write-Utf8 $path "# Findings and decisions`r`n`r`n"
  }
  $stamp=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss K")
  $entry="## {0}`r`n`r`n{1}`r`n" -f $stamp,$Text.Trim()
  Add-Content -Encoding UTF8 -LiteralPath $path -Value $entry
}

function Get-QuotaDecision($State,[string]$RouteClass="balanced",[string]$Effort="medium",[switch]$Fresh){
  $policy=Get-MissionPolicy
  $q=Get-CodexQuotaSnapshot -Fresh:$Fresh
  $action="GO"
  $reason="quota healthy or unavailable with safe fallback"

  $five=$null
  $week=$null
  if($q.five_hour){$five=[double]$q.five_hour.remaining_percent}
  if($q.weekly){$week=[double]$q.weekly.remaining_percent}

  if($null -ne $q.ordinary_usage_allowed -and $q.ordinary_usage_allowed -eq $false){
    $action="STOP"
    $reason="backend reports ordinary usage is not allowed"
  }elseif($q.rate_limit_reached_type){
    $action="STOP"
    $reason=("backend reports rate limit reached: {0}" -f $q.rate_limit_reached_type)
  }elseif($null -ne $five -and $five -le [double]$policy.five_hour_stop_remaining){
    $action="STOP"
    $reason=("5-hour remaining <= {0}%" -f $policy.five_hour_stop_remaining)
  }elseif($null -ne $week -and $week -le [double]$policy.weekly_stop_remaining){
    $action="STOP"
    $reason=("weekly remaining <= {0}%" -f $policy.weekly_stop_remaining)
  }elseif(($RouteClass -in @("strong","frontier") -or $Effort -in @("high","xhigh","max")) -and $null -ne $five -and $five -lt [double]$policy.five_hour_heavy_min_remaining){
    $action="STOP"
    $reason=("heavy task refused below {0}% 5-hour remaining" -f $policy.five_hour_heavy_min_remaining)
  }elseif(($null -ne $five -and $five -le [double]$policy.five_hour_heavy_min_remaining) -or ($null -ne $week -and $week -le [double]$policy.weekly_checkpoint_remaining)){
    $action="CHECKPOINT"
    $reason="quota pressure requires checkpoint before more work"
  }

  $minutes=0
  try{
    $minutes=((Get-Date)-[DateTimeOffset]::Parse([string]$State.session_started_at)).TotalMinutes
  }catch{
    $minutes=0
  }

  if(!$q.known -or $q.stale){
    if($minutes -ge [double]$policy.fallback_session_stop_minutes){
      $action="STOP"
      $reason="quota unavailable; fallback continuous-session safety stop"
    }elseif(($RouteClass -in @("strong","frontier") -or $Effort -in @("high","xhigh","max")) -and $minutes -ge [double]$policy.fallback_session_heavy_stop_minutes){
      $action="STOP"
      $reason="quota unavailable; do not start heavy task late in continuous session"
    }elseif($minutes -ge [double]$policy.fallback_session_checkpoint_minutes -and $action -eq "GO"){
      $action="CHECKPOINT"
      $reason="quota unavailable; fallback checkpoint cadence"
    }
  }

  return [pscustomobject]@{
    action=$action
    reason=$reason
    quota=$q
    session_minutes=[Math]::Round($minutes,1)
  }
}

function Get-NextReadyTask($State){
  Update-ReadyTasks $State
  $items=@($State.tasks|Where-Object{$_.status -eq "ready"}|Select-Object -First 1)
  if($items.Count){return $items[0]}
  return $null
}

function Add-MarkdownSection([System.Collections.Generic.List[string]]$Lines,[string]$Heading,[string]$Body){
  $Lines.Add($Heading)
  $Lines.Add("")
  if([string]::IsNullOrWhiteSpace($Body)){
    $Lines.Add("(none)")
  }else{
    $Lines.Add($Body)
  }
  $Lines.Add("")
}

function Indent-Block([object[]]$Value){
  $items=@($Value|Where-Object{$null -ne $_})
  if(!$items.Count){return "    (none)"}
  return (($items|ForEach-Object{"    "+([string]$_}) -join "`r`n")
}

function Render-TaskCard([string]$Root,$Task){
  $dir=Join-Path (Ensure-MissionDirectory $Root) "tasks"
  $path=Join-Path $dir ($Task.id+".md")
  $lines=New-Object 'System.Collections.Generic.List[string]'

  $dependsText=Join-List $Task.depends_on
  $relatedText=Join-List $Task.related

  $lines.Add(("# {0} - {1}" -f $Task.id,$Task.title))
  $lines.Add("")
  $lines.Add("## State")
  $lines.Add("")
  $lines.Add(("- Status: **{0}**" -f $Task.status))
  $lines.Add(("- Relation: {0}" -f $Task.relation))
  $lines.Add(("- Discovered from: {0}" -f $Task.discovered_from))
  $lines.Add(("- Depends on: {0}" -f $dependsText))
  $lines.Add(("- Related: {0}" -f $relatedText))
  $lines.Add(("- Risk: {0}" -f $Task.risk))
  $lines.Add("")

  Add-MarkdownSection $lines "## Why this task exists" ([string]$Task.why)

  $lines.Add("## Model plan")
  $lines.Add("")
  $lines.Add(("- Best model: {0}" -f $Task.best_model))
  $lines.Add(("- Reasoning effort: {0}" -f $Task.effort))
  $lines.Add(("- Route class: {0}" -f $Task.route_class))
  $lines.Add(("- Why this model: {0}" -f $Task.model_reason))
  $lines.Add(("- Model actually used: {0}" -f $Task.model_used))
  $lines.Add("")

  Add-MarkdownSection $lines "## Scope / files" ([string]$Task.scope)
  Add-MarkdownSection $lines "## Acceptance" ([string]$Task.acceptance)
  Add-MarkdownSection $lines "## Verification" ([string]$Task.verify)
  Add-MarkdownSection $lines "## Last result / notes" ([string]$Task.notes)

  $lines.Add("## Timestamps")
  $lines.Add("")
  $lines.Add(("- Created: {0}" -f $Task.created_at))
  $lines.Add(("- Updated: {0}" -f $Task.updated_at))

  Write-Utf8 $path (($lines -join "`r`n").Trim()+"`r`n")
}

function Render-MissionDocs([string]$Root,$State,[string]$CheckpointReason="state-update"){
  $dir=Ensure-MissionDirectory $Root
  Update-ReadyTasks $State

  $q=$State.quota
  $five="unknown"
  $week="unknown"
  if($q -and $q.five_hour){
    $five=("{0:N1}%" -f [double]$q.five_hour.remaining_percent)
  }
  if($q -and $q.weekly){
    $week=("{0:N1}%" -f [double]$q.weekly.remaining_percent)
  }

  $mission=New-Object 'System.Collections.Generic.List[string]'
  $mission.Add("# Codex Smart Factory Mission")
  $mission.Add("")
  $mission.Add(("- Mission ID: {0}" -f $State.mission_id))
  $mission.Add(("- Status: **{0}**" -f $State.status))
  $mission.Add(("- Current gate: {0}" -f $State.current_gate))
  $mission.Add(("- Execution mode: {0}" -f $State.mode))
  $mission.Add(("- Active task: {0}" -f $State.active_task_id))
  $mission.Add(("- Safe stop requested: {0}" -f $State.safe_stop_requested))
  $mission.Add(("- Safe stop reason: {0}" -f $State.safe_stop_reason))
  $mission.Add(("- 5h remaining: **{0}**" -f $five))
  $mission.Add(("- Weekly remaining: **{0}**" -f $week))
  $mission.Add(("- Last checkpoint: {0}" -f $State.last_checkpoint_at))
  $mission.Add("")

  Add-MarkdownSection $mission "## Goal" ([string]$State.goal)
  Add-MarkdownSection $mission "## Success condition" ([string]$State.success)
  Add-MarkdownSection $mission "## Constraints / non-goals" ([string]$State.constraints)
  Add-MarkdownSection $mission "## Source plan" ([string]$State.source_plan)

  $mission.Add("## Workflow contract")
  $mission.Add("")
  $mission.Add("1. TASKS.md is the task DAG/checklist visible to the user.")
  $mission.Add("2. Each task has a detailed card under tasks/<ID>.md.")
  $mission.Add("3. Exactly one task is active by default; parallel work needs independent dependencies and write scopes.")
  $mission.Add("4. Run Mission preflight before each task and long/risky verification; STOP means checkpoint and stop.")
  $mission.Add("5. Register unexpected bugs/work before expanding scope; blocker/required discoveries become dependencies.")
  $mission.Add("6. RESUME-FROM-HERE.md is the deterministic recovery entrypoint.")
  $mission.Add("7. Resume recorded state instead of replanning unless fresh evidence invalidates the graph.")

  Write-Utf8 (Join-Path $dir "MISSION.md") (($mission -join "`r`n").Trim()+"`r`n")

  $table=New-Object 'System.Collections.Generic.List[string]'
  $table.Add("# Task graph and checklist")
  $table.Add("")
  $table.Add("| ID | Status | Task | Why | Depends on | Related | Relation | Discovered from | Best model | Effort | Why model | Model used | Scope | Verify | Updated |")
  $table.Add("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")

  foreach($task in @($State.tasks)){
    $cells=@(
      (Markdown-Safe $task.id),
      (Markdown-Safe $task.status),
      (Markdown-Safe $task.title),
      (Markdown-Safe $task.why),
      (Markdown-Safe (Join-List $task.depends_on)),
      (Markdown-Safe (Join-List $task.related)),
      (Markdown-Safe $task.relation),
      (Markdown-Safe $task.discovered_from),
      (Markdown-Safe $task.best_model),
      (Markdown-Safe $task.effort),
      (Markdown-Safe $task.model_reason),
      (Markdown-Safe $task.model_used),
      (Markdown-Safe $task.scope),
      (Markdown-Safe $task.verify),
      (Markdown-Safe $task.updated_at)
    )
    $row="| "+($cells -join " | ")+" |"
    $table.Add($row)
    Render-TaskCard $Root $task
  }

  Write-Utf8 (Join-Path $dir "TASKS.md") (($table -join "`r`n")+"`r`n")

  $progressPath=Join-Path $dir "PROGRESS.md"
  if(!(Test-Path -LiteralPath $progressPath)){
    Write-Utf8 $progressPath "# Progress`r`n`r`n"
  }

  $findingsPath=Join-Path $dir "FINDINGS.md"
  if(!(Test-Path -LiteralPath $findingsPath)){
    Write-Utf8 $findingsPath "# Findings and decisions`r`n`r`n"
  }

  $git=Get-GitSnapshot $Root

  $active=$null
  if($State.active_task_id){
    $active=Get-Task $State ([string]$State.active_task_id)
  }

  $next=Get-NextReadyTask $State

  $nextAction="Reconcile blockers/completion; do not invent a new task without evidence."
  if($State.safe_stop_requested){
    $nextAction="Do not start new work. Resume only after quota/session guard clears."
  }elseif($active -and $active.status -eq "doing"){
    $nextAction=("Continue {0} from its task card, then verify and checkpoint." -f $active.id)
  }elseif($next){
    $nextAction=("Start {0} - {1} after preflight." -f $next.id,$next.title)
  }

  $activeSummary="none"
  if($active){
    $activeSummary=("{0} - {1} [{2}]" -f $active.id,$active.title,$active.status)
  }

  $missionScript=Join-Path (Get-FactoryHome) "src\mission\Mission.ps1"

  $resume=New-Object 'System.Collections.Generic.List[string]'
  $resume.Add("# RESUME FROM HERE")
  $resume.Add("")
  $resume.Add("> First recovery read after crash, context compaction, usage-limit pause, app close, or a new Codex session.")
  $resume.Add("")
  $resume.Add("## Mission")
  $resume.Add("")
  $resume.Add(("- Mission ID: {0}" -f $State.mission_id))
  $resume.Add(("- Mission status: **{0}**" -f $State.status))
  $resume.Add(("- Gate: {0}" -f $State.current_gate))
  $resume.Add(("- Checkpoint reason: {0}" -f $CheckpointReason))
  $resume.Add(("- Checkpoint time: {0}" -f $State.last_checkpoint_at))
  $resume.Add(("- Active task: **{0}**" -f $activeSummary))
  $resume.Add(("- Safe stop requested: **{0}**" -f $State.safe_stop_requested))
  $resume.Add(("- Safe stop reason: {0}" -f $State.safe_stop_reason))
  $resume.Add("")
  $resume.Add("## Quota snapshot")
  $resume.Add("")

  $quotaSource="unavailable"
  $ordinary=""
  $reached=""
  if($q){
    if($q.source){$quotaSource=[string]$q.source}
    if($null -ne $q.ordinary_usage_allowed){$ordinary=[string]$q.ordinary_usage_allowed}
    if($q.rate_limit_reached_type){$reached=[string]$q.rate_limit_reached_type}
  }

  $resume.Add(("- Source: {0}" -f $quotaSource))
  $resume.Add(("- 5h remaining: **{0}**" -f $five))
  $resume.Add(("- Weekly remaining: **{0}**" -f $week))
  $resume.Add(("- Backend ordinary usage allowed: {0}" -f $ordinary))
  $resume.Add(("- Reached type: {0}" -f $reached))
  $resume.Add("")
  $resume.Add("## Exact next action")
  $resume.Add("")
  $resume.Add(("**{0}**" -f $nextAction))
  $resume.Add("")
  $resume.Add("## Recovery protocol")
  $resume.Add("")
  $resume.Add("1. Read this file first.")
  $resume.Add("2. Read MISSION.md and TASKS.md.")
  $resume.Add("3. Read only the active/next task card under tasks/.")
  $resume.Add("4. Read the tail of PROGRESS.md and FINDINGS.md; do not replay the whole history unless necessary.")
  $resume.Add("5. Reconcile the Git snapshot below with the live working tree.")
  $resume.Add("6. Run Mission resume, then Mission preflight before heavy work.")
  $resume.Add("7. Continue the recorded task; do not restart planning unless fresh evidence invalidates dependencies or acceptance criteria.")
  $resume.Add("")
  $resume.Add("Resume command:")
  $resume.Add("")
  $resumeCommand='    & "'+$missionScript+'" resume -Root "'+$Root+'"'
  $resume.Add($resumeCommand)
  $resume.Add("")
  $resume.Add("## Git snapshot")
  $resume.Add("")
  $resume.Add(("- Branch: {0}" -f $git.branch))
  $resume.Add("")
  $resume.Add("### git status --short")
  $resume.Add("")
  $resume.Add((Indent-Block $git.status))
  $resume.Add("")
  $resume.Add("### git diff --stat")
  $resume.Add("")
  $resume.Add((Indent-Block $git.diff_stat))
  $resume.Add("")

  Add-MarkdownSection $resume "## Mission goal" ([string]$State.goal)
  Add-MarkdownSection $resume "## Success condition" ([string]$State.success)

  Write-Utf8 (Join-Path $dir "RESUME-FROM-HERE.md") (($resume -join "`r`n").Trim()+"`r`n")

  $stopPath=Join-Path $dir "SAFE-STOP.md"
  if($State.safe_stop_requested){
    $stopLines=@(
      "# SAFE STOP REQUESTED",
      "",
      "Do not start new implementation, routed workers, broad verification, migration, installation, or destructive work until Mission resume/preflight clears this state.",
      "",
      ("Reason: {0}" -f $State.safe_stop_reason),
      ("Checkpoint: {0}" -f $State.last_checkpoint_at),
      "Resume file: RESUME-FROM-HERE.md"
    )
    Write-Utf8 $stopPath (($stopLines -join "`r`n")+"`r`n")
  }elseif(Test-Path -LiteralPath $stopPath){
    Remove-Item -LiteralPath $stopPath -Force -ErrorAction SilentlyContinue
  }
}

function Save-MissionState([string]$Root,$State,[string]$CheckpointReason="state-update"){
  Write-MissionJson $Root $State
  Render-MissionDocs $Root $State $CheckpointReason
  Write-MissionJson $Root $State
}

function Validate-MissionPlan($State){
  $errors=New-Object 'System.Collections.Generic.List[string]'
  $ids=@{}

  foreach($t in @($State.tasks)){
    if(!$t.id){
      $errors.Add("task missing id")
      continue
    }

    $taskId=[string]$t.id
    if($ids.ContainsKey($taskId)){
      $errors.Add(("duplicate task id: {0}" -f $taskId))
    }else{
      $ids[$taskId]=$t
    }

    if([string]::IsNullOrWhiteSpace([string]$t.title)){
      $errors.Add(("{0}: missing task title" -f $taskId))
    }
    if([string]::IsNullOrWhiteSpace([string]$t.why)){
      $errors.Add(("{0}: missing why" -f $taskId))
    }
    if([string]::IsNullOrWhiteSpace([string]$t.verify) -and $t.status -notin @("deferred","out-of-scope")){
      $errors.Add(("{0}: missing verification" -f $taskId))
    }
    if([string]::IsNullOrWhiteSpace([string]$t.best_model) -and $t.status -notin @("deferred","out-of-scope")){
      $errors.Add(("{0}: missing model route" -f $taskId))
    }
  }

  foreach($t in @($State.tasks)){
    $taskId=[string]$t.id
    foreach($d in @($t.depends_on)){
      if(!$d){continue}
      $dep=[string]$d
      if($dep -eq $taskId){
        $errors.Add(("{0}: self dependency" -f $taskId))
      }elseif(!$ids.ContainsKey($dep)){
        $errors.Add(("{0}: missing dependency {1}" -f $taskId,$dep))
      }
    }
  }

  $doing=@($State.tasks|Where-Object{$_.status -eq "doing"})
  if($doing.Count -gt 1){
    $errors.Add("multiple doing tasks without explicit parallel controller")
  }

  $active=@($State.tasks|Where-Object{$_.status -notin @("deferred","out-of-scope")})
  $ind=@{}
  $edges=@{}

  foreach($t in $active){
    $taskId=[string]$t.id
    $ind[$taskId]=0
    $edges[$taskId]=New-Object 'Collections.Generic.List[string]'
  }

  foreach($t in $active){
    $taskId=[string]$t.id
    foreach($d in @($t.depends_on)){
      $dep=[string]$d
      if($ind.ContainsKey($dep)){
        $ind[$taskId]=[int]$ind[$taskId]+1
        $edges[$dep].Add($taskId)
      }
    }
  }

  $queue=New-Object 'Collections.Generic.Queue[string]'
  foreach($key in @($ind.Keys)){
    if([int]$ind[$key] -eq 0){
      $queue.Enqueue([string]$key)
    }
  }

  $processed=0
  while($queue.Count){
    $x=$queue.Dequeue()
    $processed++
    foreach($n in $edges[$x]){
      $ind[$n]=[int]$ind[$n]-1
      if([int]$ind[$n] -eq 0){
        $queue.Enqueue([string]$n)
      }
    }
  }

  if($processed -lt $active.Count){
    $errors.Add("task dependency graph contains a cycle")
  }

  return [pscustomobject]@{
    valid=($errors.Count -eq 0)
    errors=@($errors)
  }
}

function Invoke-MissionCheckpoint([string]$Root,$State,[string]$Reason="checkpoint",[switch]$FreshQuota){
  $qd=Get-QuotaDecision $State "balanced" "medium" -Fresh:$FreshQuota
  $State.quota=$qd.quota
  $State.last_checkpoint_at=(Get-Date).ToString("o")

  if($qd.action -eq "STOP"){
    $State.safe_stop_requested=$true
    $State.safe_stop_reason=$qd.reason
    if($State.status -ne "done"){
      $State.status="paused"
      $State.current_gate="pause"
    }
  }

  Save-MissionState $Root $State $Reason
  $entry="- Checkpoint: **{0}**`r`n- Quota action: **{1}** - {2}" -f $Reason,$qd.action,$qd.reason
  Append-Progress $Root $entry
  return $qd
}
