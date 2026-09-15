param(
  [ValidateSet("init","add-task","discover","start-task","progress","finding","complete-task","block-task","checkpoint","pause","resume","preflight","watchdog","validate","status","finish")][string]$Action="status",
  [string]$Root=(Get-Location).Path,
  [string]$Goal="",
  [string]$Success="",
  [string]$PlanText="",
  [string]$Constraints="",
  [ValidateSet("auto","manual")][string]$Mode="auto",
  [string]$Id="",
  [string]$Title="",
  [string]$Why="",
  [string]$DependsOn="",
  [string]$Related="",
  [ValidateSet("plan","blocker","required","related","follow-up","out-of-scope")][string]$Relation="plan",
  [string]$DiscoveredFrom="plan",
  [string]$Scope="",
  [string]$Acceptance="",
  [string]$Verify="",
  [string]$Risk="normal",
  [string]$Message="",
  [string]$Verification="",
  [string]$ModelUsed="",
  [switch]$Verified,
  [switch]$FreshQuota,
  [switch]$Force,
  [switch]$Quiet
)
$ErrorActionPreference="Stop"
. (Join-Path $PSScriptRoot "MissionCommon.ps1")
$routeScript=Join-Path (Split-Path -Parent $PSScriptRoot) "router\Router.ps1"
if(Test-Path $routeScript){. $routeScript}

try{$Root=(Get-Item -LiteralPath $Root).FullName}catch{throw "Root does not exist: $Root"}

function Require-Mission {
  $s=Read-MissionState $Root
  if(!$s){throw "No Smart Factory mission exists in $Root. Run Mission.ps1 init first."}
  return $s
}

function New-TaskObject($State,[string]$TaskTitle,[string]$TaskWhy,[string[]]$Deps,[string[]]$Rel,[string]$RelType,[string]$From,[string]$TaskScope,[string]$TaskAcceptance,[string]$TaskVerify,[string]$TaskRisk){
  if([string]::IsNullOrWhiteSpace($TaskTitle)){throw "Task title is required."}
  if([string]::IsNullOrWhiteSpace($TaskWhy)){throw "Task why is required."}
  if($RelType -ne "out-of-scope" -and [string]::IsNullOrWhiteSpace($TaskVerify)){throw "Task verification is required for executable tasks."}

  $route=$null
  if(Get-Command Resolve-Route -ErrorAction SilentlyContinue){
    $routeText="$TaskTitle`nWhy: $TaskWhy`nRisk: $TaskRisk`nScope: $TaskScope`nAcceptance: $TaskAcceptance`nVerification: $TaskVerify"
    try{$route=Resolve-Route $routeText}catch{}
  }
  $now=(Get-Date).ToString("o")
  $task=[pscustomobject]@{
    id=(Get-NextTaskId $State)
    status=if($RelType -eq "out-of-scope"){"deferred"}else{"todo"}
    title=$TaskTitle
    why=$TaskWhy
    depends_on=@($Deps)
    related=@($Rel)
    relation=$RelType
    discovered_from=$From
    scope=$TaskScope
    acceptance=$TaskAcceptance
    verify=$TaskVerify
    risk=$TaskRisk
    block_kind=""
    best_model=if($route -and $route.model){[string]$route.model}else{"current-lead"}
    effort=if($route){[string]$route.effort}else{"medium"}
    route_class=if($route){[string]$route.route_class}else{"balanced"}
    model_reason=if($route){[string]$route.reason}else{"router unavailable; stay local"}
    model_used=""
    notes=""
    created_at=$now
    updated_at=$now
  }
  if($task.status -ne "deferred" -and (Test-TaskDependenciesDone $State $task)){$task.status="ready"}
  return $task
}

function Add-TaskToState($State,$Task){
  $State.tasks=@($State.tasks)+@($Task)
  Update-ReadyTasks $State
  $State.current_gate="plan"
  Save-MissionState $Root $State "task-added"
  Append-Progress $Root ("- Added **$($Task.id)** — $($Task.title)`r`n- Best model: $($Task.best_model) / $($Task.effort)`r`n- Relation: $($Task.relation); discovered from: $($Task.discovered_from)")
}

switch($Action){
  "init"{
    $existing=Read-MissionState $Root
    if($existing -and !$Force){
      Write-Host ("Mission already exists: "+$existing.mission_id+" status="+$existing.status)
      Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
      exit 0
    }
    if([string]::IsNullOrWhiteSpace($Goal)){throw "-Goal is required."}
    if([string]::IsNullOrWhiteSpace($Success)){throw "-Success is required and must describe measurable completion."}
    $now=(Get-Date).ToString("o")
    $state=[pscustomobject]@{
      version=2
      mission_id=((Get-Date -Format "yyyyMMdd-HHmmss")+"-"+(Get-ShortHash ($Root+"|"+$Goal)).Substring(0,8))
      root=$Root
      goal=$Goal
      success=$Success
      source_plan=$PlanText
      constraints=$Constraints
      mode=$Mode
      status="active"
      current_gate="plan"
      active_task_id=""
      safe_stop_requested=$false
      safe_stop_reason=""
      created_at=$now
      updated_at=$now
      session_started_at=$now
      last_checkpoint_at=$now
      quota=(Get-CodexQuotaSnapshot)
      tasks=@()
    }
    Save-MissionState $Root $state "mission-init"
    Append-Progress $Root ("- Mission initialized: **$($state.mission_id)**`r`n- Goal: $Goal`r`n- Success: $Success")
    Write-Host ("MISSION INITIALIZED: "+$state.mission_id)
    Write-Host "Next: decompose the plan into atomic verifiable tasks using add-task, then run validate."
  }

  "add-task"{
    $state=Require-Mission
    $task=New-TaskObject $state $Title $Why (Split-List $DependsOn) (Split-List $Related) $Relation $DiscoveredFrom $Scope $Acceptance $Verify $Risk
    Add-TaskToState $state $task
    Write-Host ("TASK ADDED: {0} | status={1} | best_model={2} | effort={3}" -f $task.id,$task.status,$task.best_model,$task.effort)
  }

  "discover"{
    $state=Require-Mission
    if([string]::IsNullOrWhiteSpace($DiscoveredFrom) -or $DiscoveredFrom -eq "plan"){if($state.active_task_id){$DiscoveredFrom=[string]$state.active_task_id}else{throw "-DiscoveredFrom is required when no task is active."}}
    $parent=Get-Task $state $DiscoveredFrom
    if(!$parent){throw "Discovery parent task not found: $DiscoveredFrom"}
    $deps=Split-List $DependsOn
    if(!$deps.Count){$deps=@($parent.depends_on)}
    $rel=Split-List $Related
    if($rel -notcontains $parent.id){$rel=@($rel)+@($parent.id)}
    $task=New-TaskObject $state $Title $Why $deps $rel $Relation $parent.id $Scope $Acceptance $Verify $Risk
    $state.tasks=@($state.tasks)+@($task)
    if(@($parent.related) -notcontains $task.id){$parent.related=@((@($parent.related)+@($task.id)) | Select-Object -Unique)}

    if($Relation -in @("blocker","required")){
      $parent.depends_on=@((@($parent.depends_on)+@($task.id)) | Select-Object -Unique)
      if($parent.status -in @("doing","verify","ready","todo")){
        $parent.status="blocked"
        $parent.block_kind="dependency"
      }
      if($state.active_task_id -eq $parent.id){$state.active_task_id=""}
    }
    Update-ReadyTasks $state
    Save-MissionState $Root $state "discovery-added"
    Append-Finding $Root ("- Discovered **$($task.id)** during **$($parent.id)**`r`n- Relation: **$Relation**`r`n- What: $Title`r`n- Why: $Why`r`n- Routed model: $($task.best_model) / $($task.effort)")
    Append-Progress $Root ("- Discovery registered: **$($task.id)** from **$($parent.id)** as **$Relation**. It was added to the task graph before implementation.")
    Write-Host ("DISCOVERY ADDED: {0} <- {1} | relation={2} | best_model={3}/{4}" -f $task.id,$parent.id,$Relation,$task.best_model,$task.effort)
  }

  "validate"{
    $state=Require-Mission
    Update-ReadyTasks $state
    $v=Validate-MissionPlan $state
    Save-MissionState $Root $state "plan-validation"
    if(!$v.valid){Write-Host "PLAN INVALID";foreach($e in $v.errors){Write-Host (" - "+$e)};exit 2}
    if(@($state.tasks).Count -eq 0){Write-Host "PLAN INVALID`n - no tasks";exit 2}
    $state.current_gate="execute"
    Save-MissionState $Root $state "plan-validated"
    Append-Progress $Root "- Plan validation: **PASS**. Task graph dependencies, verification fields, and model routes are coherent."
    Write-Host ("PLAN VALID | tasks="+@($state.tasks).Count)
  }

  "preflight"{
    $state=Require-Mission
    $task=if($Id){Get-Task $state $Id}elseif($state.active_task_id){Get-Task $state ([string]$state.active_task_id)}else{Get-NextReadyTask $state}
    $class=if($task){[string]$task.route_class}else{"balanced"}
    $effort=if($task){[string]$task.effort}else{"medium"}
    $qd=Get-QuotaDecision $state $class $effort -Fresh:$FreshQuota
    $state.quota=$qd.quota
    if($qd.action -eq "STOP"){
      $state.safe_stop_requested=$true;$state.safe_stop_reason=$qd.reason;$state.status="paused";$state.current_gate="pause";$state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "preflight-stop"
      Append-Progress $Root ("- **SAFE STOP** before new work: $($qd.reason)")
    }elseif($qd.action -eq "CHECKPOINT"){
      [void](Invoke-MissionCheckpoint $Root $state "preflight-quota-pressure")
    }else{Save-MissionState $Root $state "preflight-go"}
    $taskName="none"
    if($task){$taskName=[string]$task.id}
    $fiveText="unknown"
    if($qd.quota.five_hour){$fiveText=("{0:N1}%" -f $qd.quota.five_hour.remaining_percent)}
    $weekText="unknown"
    if($qd.quota.weekly){$weekText=("{0:N1}%" -f $qd.quota.weekly.remaining_percent)}
    Write-Host ("PREFLIGHT: {0} | task={1} | route={2}/{3} | 5h={4} | weekly={5} | {6}" -f $qd.action,$taskName,$class,$effort,$fiveText,$weekText,$qd.reason)
    if($qd.action -eq "STOP"){exit 3}
  }

  "start-task"{
    $state=Require-Mission
    $v=Validate-MissionPlan $state
    if(!$v.valid){throw "Plan is invalid. Run validate and fix the task graph before execution."}
    if(!$Id){$next=Get-NextReadyTask $state;if(!$next){throw "No ready task."};$Id=[string]$next.id}
    $task=Get-Task $state $Id
    if(!$task){throw "Task not found: $Id"}
    if(!(Test-TaskDependenciesDone $state $task)){throw "$Id has incomplete dependencies: $(Join-List $task.depends_on)"}
    $other=@($state.tasks|Where-Object{$_.status -eq "doing" -and $_.id -ne $Id})
    if($other.Count){throw "Another task is already doing: $($other[0].id). Complete/checkpoint it before starting $Id."}
    if($task.status -in @("done","deferred")){throw "$Id cannot be started from status $($task.status)."}

    $qd=Get-QuotaDecision $state ([string]$task.route_class) ([string]$task.effort) -Fresh:$FreshQuota
    $state.quota=$qd.quota
    if($qd.action -eq "STOP"){
      $state.safe_stop_requested=$true;$state.safe_stop_reason=$qd.reason;$state.status="paused";$state.current_gate="pause";$state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "start-refused-quota"
      Append-Progress $Root ("- Start refused for **$Id**: $($qd.reason). Resume file refreshed.")
      Write-Host ("SAFE STOP: refusing to start {0} | {1}" -f $Id,$qd.reason);exit 3
    }
    if($qd.action -eq "CHECKPOINT"){[void](Invoke-MissionCheckpoint $Root $state "before-task-quota-checkpoint")}

    $task.status="doing";$task.updated_at=(Get-Date).ToString("o")
    $task.model_used=if($ModelUsed){$ModelUsed}else{"current-lead"}
    $state.active_task_id=$task.id;$state.status="active";$state.current_gate="execute";$state.safe_stop_requested=$false;$state.safe_stop_reason=""
    Save-MissionState $Root $state "task-start"
    Append-Progress $Root ("- Started **$Id** — $($task.title)`r`n- Planned model: $($task.best_model) / $($task.effort); actual so far: $($task.model_used)")
    Write-Host ("TASK STARTED: {0} | best_model={1}/{2} | actual={3}" -f $Id,$task.best_model,$task.effort,$task.model_used)
  }

  "progress"{
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}
    $task=if($Id){Get-Task $state $Id}else{$null}
    if($task){
      if($ModelUsed){$task.model_used=$ModelUsed}
      if($Message){$task.notes=((([string]$task.notes).Trim()+"`r`n"+$Message).Trim())}
      $task.updated_at=(Get-Date).ToString("o")
    }
    Save-MissionState $Root $state "progress-update"
    $progressLines=New-Object 'System.Collections.Generic.List[string]'
    $progressTask="mission"
    if($Id){$progressTask=$Id}
    $progressLines.Add("- Task: **$progressTask**")
    if($Message){$progressLines.Add("- "+$Message)}
    if($Verification){$progressLines.Add("- Verification: "+$Verification)}
    if($ModelUsed){$progressLines.Add("- Model used: "+$ModelUsed)}
    Append-Progress $Root ($progressLines -join "`r`n")
    Write-Host "PROGRESS SAVED"
  }

  "finding"{
    $state=Require-Mission
    if(!$Message){throw "-Message is required."}
    $findingTask="mission"
    if($Id){$findingTask=$Id}elseif($state.active_task_id){$findingTask=[string]$state.active_task_id}
    Append-Finding $Root ("- Task: **$findingTask**`r`n- $Message")
    Save-MissionState $Root $state "finding"
    Write-Host "FINDING SAVED"
  }

  "block-task"{
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}
    $task=Get-Task $state $Id
    if(!$task){throw "Task not found: $Id"}
    $task.status="blocked";$task.block_kind="manual";$task.notes=((([string]$task.notes).Trim()+"`r`nBLOCKED: "+$Message).Trim());$task.updated_at=(Get-Date).ToString("o")
    if($state.active_task_id -eq $Id){$state.active_task_id=""}
    Save-MissionState $Root $state "task-blocked"
    Append-Progress $Root ("- **$Id BLOCKED** — $Message")
    Write-Host "TASK BLOCKED: $Id"
  }

  "complete-task"{
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}
    $task=Get-Task $state $Id
    if(!$task){throw "Task not found: $Id"}
    if(!(Test-TaskDependenciesDone $state $task)){throw "$Id cannot complete; dependencies are not done."}
    if($ModelUsed){$task.model_used=$ModelUsed}
    if($Verification){$task.notes=((([string]$task.notes).Trim()+"`r`nVerification: "+$Verification).Trim())}
    $task.updated_at=(Get-Date).ToString("o")
    if(!$Verified){
      $task.status="verify";$state.current_gate="verify"
      Save-MissionState $Root $state "verification-required"
      Append-Progress $Root ("- **$Id** implementation reached verification gate. Not marked done because `-Verified` was not supplied.`r`n- Evidence: $Verification")
      Write-Host "VERIFY REQUIRED: $Id is not done yet.";exit 4
    }
    $task.status="done"
    if($state.active_task_id -eq $Id){$state.active_task_id=""}
    Update-ReadyTasks $state
    $state.current_gate="execute"
    $qd=Invoke-MissionCheckpoint $Root $state ("task-complete-"+$Id)
    Append-Progress $Root ("- **$Id DONE** with verification evidence: $Verification")
    $next=Get-NextReadyTask $state
    $nextId="none"
    if($next){$nextId=[string]$next.id}
    Write-Host ("TASK DONE: {0} | next={1} | quota_action={2}" -f $Id,$nextId,$qd.action)
  }

  "checkpoint"{
    $state=Require-Mission
    $reason=if($Message){$Message}else{"manual-checkpoint"}
    $qd=Invoke-MissionCheckpoint $Root $state $reason -FreshQuota:$FreshQuota
    Write-Host ("CHECKPOINT SAVED | quota_action={0} | {1}" -f $qd.action,$qd.reason)
  }

  "pause"{
    $state=Require-Mission
    $state.status="paused";$state.current_gate="pause";$state.safe_stop_requested=$true;$state.safe_stop_reason=if($Message){$Message}else{"manual pause"}
    $qd=Invoke-MissionCheckpoint $Root $state "pause"
    Write-Host ("MISSION PAUSED | "+$state.safe_stop_reason)
  }

  "resume"{
    $state=Require-Mission
    $state.session_started_at=(Get-Date).ToString("o")
    $qd=Get-QuotaDecision $state "balanced" "medium" -Fresh
    $state.quota=$qd.quota
    if($qd.action -eq "STOP"){
      $state.status="paused";$state.current_gate="pause";$state.safe_stop_requested=$true;$state.safe_stop_reason=$qd.reason
      Save-MissionState $Root $state "resume-refused-quota"
      Write-Host ("RESUME REFUSED: "+$qd.reason)
      Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
      exit 3
    }
    $state.status="active";$state.current_gate=if($state.active_task_id){"execute"}else{"execute"};$state.safe_stop_requested=$false;$state.safe_stop_reason=""
    Update-ReadyTasks $state
    Save-MissionState $Root $state "resume"
    Append-Progress $Root "- Mission resumed from durable state; session fallback timer reset."
    Write-Host "MISSION RESUMED"
    Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
  }

  "watchdog"{
    $state=Read-MissionState $Root
    if(!$state -or $state.status -eq "done"){exit 0}
    $policy=Get-MissionPolicy
    $qd=Get-QuotaDecision $state "balanced" "medium" -Fresh:$FreshQuota
    $state.quota=$qd.quota
    $age=999
    try{$age=((Get-Date)-[DateTimeOffset]::Parse([string]$state.last_checkpoint_at)).TotalMinutes}catch{}
    if($qd.action -eq "STOP"){
      $state.status="paused";$state.current_gate="pause";$state.safe_stop_requested=$true;$state.safe_stop_reason=$qd.reason;$state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "watchdog-safe-stop"
      Append-Progress $Root ("- **WATCHDOG SAFE STOP REQUESTED** — $($qd.reason)")
      if(!$Quiet){Write-Host ("WATCHDOG STOP: "+$qd.reason)}
    }elseif($age -ge [double]$policy.checkpoint_interval_minutes){
      [void](Invoke-MissionCheckpoint $Root $state "watchdog-periodic")
      if(!$Quiet){Write-Host "WATCHDOG CHECKPOINT"}
    }else{
      Save-MissionState $Root $state "watchdog-refresh"
    }
  }

  "status"{
    $state=Require-Mission
    Update-ReadyTasks $state
    Save-MissionState $Root $state "status"
    $v=Validate-MissionPlan $state
    $counts=@{}
    foreach($s in @("todo","ready","doing","blocked","verify","done","deferred")){$counts[$s]=@($state.tasks|Where-Object{$_.status -eq $s}).Count}
    Write-Host ("MISSION {0} | status={1} gate={2} active={3}" -f $state.mission_id,$state.status,$state.current_gate,$state.active_task_id)
    Write-Host ("Tasks: ready={0} doing={1} blocked={2} verify={3} done={4} deferred={5}" -f $counts.ready,$counts.doing,$counts.blocked,$counts.verify,$counts.done,$counts.deferred)
    Write-Host ("Plan valid: "+$v.valid)
    Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
  }

  "finish"{
    $state=Require-Mission
    $open=@($state.tasks|Where-Object{$_.status -notin @("done","deferred")})
    if($open.Count){throw "Mission cannot finish; open tasks: "+(($open|ForEach-Object{$_.id+":"+$_.status}) -join ", ")}
    if(!$Verified){throw "Final mission completion requires -Verified and final verification evidence."}
    $state.status="done";$state.current_gate="done";$state.active_task_id="";$state.safe_stop_requested=$false;$state.safe_stop_reason="";$state.last_checkpoint_at=(Get-Date).ToString("o")
    Save-MissionState $Root $state "mission-done"
    Append-Progress $Root ("- **MISSION DONE**`r`n- Final verification: $Verification")
    Write-Host "MISSION DONE"
  }
}
