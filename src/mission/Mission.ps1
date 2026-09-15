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
if(Test-Path -LiteralPath $routeScript){
  . $routeScript
}

try{
  $Root=(Get-Item -LiteralPath $Root).FullName
}catch{
  throw ("Root does not exist: {0}" -f $Root)
}

function Require-Mission {
  $s=Read-MissionState $Root
  if(!$s){
    throw ("No Smart Factory mission exists in {0}. Run Mission.ps1 init first." -f $Root)
  }
  return $s
}

function New-TaskObject(
  $State,
  [string]$TaskTitle,
  [string]$TaskWhy,
  [string[]]$Deps,
  [string[]]$Rel,
  [string]$RelType,
  [string]$From,
  [string]$TaskScope,
  [string]$TaskAcceptance,
  [string]$TaskVerify,
  [string]$TaskRisk
){
  if([string]::IsNullOrWhiteSpace($TaskTitle)){throw "Task title is required."}
  if([string]::IsNullOrWhiteSpace($TaskWhy)){throw "Task why is required."}
  if($RelType -ne "out-of-scope" -and [string]::IsNullOrWhiteSpace($TaskVerify)){
    throw "Task verification is required for executable tasks."
  }

  $route=$null
  if(Get-Command Resolve-Route -ErrorAction SilentlyContinue){
    $routeText="{0}`nWhy: {1}`nRisk: {2}`nScope: {3}`nAcceptance: {4}`nVerification: {5}" -f $TaskTitle,$TaskWhy,$TaskRisk,$TaskScope,$TaskAcceptance,$TaskVerify
    try{
      $route=Resolve-Route $routeText
    }catch{
      $route=$null
    }
  }

  $status="todo"
  if($RelType -eq "out-of-scope"){$status="deferred"}

  $bestModel="current-lead"
  $effort="medium"
  $routeClass="balanced"
  $modelReason="router unavailable; stay local"
  if($route){
    if($route.model){$bestModel=[string]$route.model}
    if($route.effort){$effort=[string]$route.effort}
    if($route.route_class){$routeClass=[string]$route.route_class}
    if($route.reason){$modelReason=[string]$route.reason}
  }

  $now=(Get-Date).ToString("o")
  $task=[pscustomobject][ordered]@{
    id=(Get-NextTaskId $State)
    status=$status
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
    best_model=$bestModel
    effort=$effort
    route_class=$routeClass
    model_reason=$modelReason
    model_used=""
    notes=""
    created_at=$now
    updated_at=$now
  }

  if($task.status -ne "deferred"){
    if(Test-TaskDependenciesDone $State $task){
      $task.status="ready"
    }
  }
  return $task
}

function Add-TaskToState($State,$Task){
  $State.tasks=@($State.tasks)+@($Task)
  Update-ReadyTasks $State
  $State.current_gate="plan"
  Save-MissionState $Root $State "task-added"
  $entry="- Added **{0}** - {1}`r`n- Best model: {2} / {3}`r`n- Relation: {4}; discovered from: {5}" -f $Task.id,$Task.title,$Task.best_model,$Task.effort,$Task.relation,$Task.discovered_from
  Append-Progress $Root $entry
}

switch($Action){
  "init" {
    $existing=Read-MissionState $Root
    if($existing -and !$Force){
      Write-Host ("Mission already exists: {0} status={1}" -f $existing.mission_id,$existing.status)
      Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
      exit 0
    }

    if([string]::IsNullOrWhiteSpace($Goal)){throw "-Goal is required."}
    if([string]::IsNullOrWhiteSpace($Success)){
      throw "-Success is required and must describe measurable completion."
    }

    $now=(Get-Date).ToString("o")
    $missionId=(Get-Date -Format "yyyyMMdd-HHmmss")+"-"+(Get-ShortHash ($Root+"|"+$Goal)).Substring(0,8)
    $initialQuota=Get-CodexQuotaSnapshot

    $state=[pscustomobject][ordered]@{
      version=2
      mission_id=$missionId
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
      quota=$initialQuota
      tasks=@()
    }

    Save-MissionState $Root $state "mission-init"
    $entry="- Mission initialized: **{0}**`r`n- Goal: {1}`r`n- Success: {2}" -f $state.mission_id,$Goal,$Success
    Append-Progress $Root $entry
    Write-Host ("MISSION INITIALIZED: {0}" -f $state.mission_id)
    Write-Host "Next: decompose the plan into atomic verifiable tasks using add-task, then run validate."
  }

  "add-task" {
    $state=Require-Mission
    $deps=@(Split-List $DependsOn)
    $rel=@(Split-List $Related)
    $task=New-TaskObject $state $Title $Why $deps $rel $Relation $DiscoveredFrom $Scope $Acceptance $Verify $Risk
    Add-TaskToState $state $task
    Write-Host ("TASK ADDED: {0} | status={1} | best_model={2} | effort={3}" -f $task.id,$task.status,$task.best_model,$task.effort)
  }

  "discover" {
    $state=Require-Mission

    if([string]::IsNullOrWhiteSpace($DiscoveredFrom) -or $DiscoveredFrom -eq "plan"){
      if($state.active_task_id){
        $DiscoveredFrom=[string]$state.active_task_id
      }else{
        throw "-DiscoveredFrom is required when no task is active."
      }
    }

    $parent=Get-Task $state $DiscoveredFrom
    if(!$parent){throw ("Discovery parent task not found: {0}" -f $DiscoveredFrom)}

    $deps=@(Split-List $DependsOn)
    if(!$deps.Count){$deps=@($parent.depends_on)}

    $rel=@(Split-List $Related)
    if($rel -notcontains $parent.id){
      $rel=@($rel)+@($parent.id)
    }

    $task=New-TaskObject $state $Title $Why $deps $rel $Relation $parent.id $Scope $Acceptance $Verify $Risk
    $state.tasks=@($state.tasks)+@($task)

    if(@($parent.related) -notcontains $task.id){
      $parent.related=@((@($parent.related)+@($task.id)) | Select-Object -Unique)
    }

    if($Relation -in @("blocker","required")){
      $parent.depends_on=@((@($parent.depends_on)+@($task.id)) | Select-Object -Unique)
      if($parent.status -in @("doing","verify","ready","todo")){
        $parent.status="blocked"
        $parent.block_kind="dependency"
      }
      if($state.active_task_id -eq $parent.id){
        $state.active_task_id=""
      }
    }

    Update-ReadyTasks $state
    Save-MissionState $Root $state "discovery-added"

    $finding="- Discovered **{0}** during **{1}**`r`n- Relation: **{2}**`r`n- What: {3}`r`n- Why: {4}`r`n- Routed model: {5} / {6}" -f $task.id,$parent.id,$Relation,$Title,$Why,$task.best_model,$task.effort
    Append-Finding $Root $finding

    $progress="- Discovery registered: **{0}** from **{1}** as **{2}**. It was added to the task graph before implementation." -f $task.id,$parent.id,$Relation
    Append-Progress $Root $progress

    Write-Host ("DISCOVERY ADDED: {0} <- {1} | relation={2} | best_model={3}/{4}" -f $task.id,$parent.id,$Relation,$task.best_model,$task.effort)
  }

  "validate" {
    $state=Require-Mission
    Update-ReadyTasks $state
    $v=Validate-MissionPlan $state
    Save-MissionState $Root $state "plan-validation"

    if(!$v.valid){
      Write-Host "PLAN INVALID"
      foreach($e in $v.errors){Write-Host (" - {0}" -f $e)}
      exit 2
    }

    if(@($state.tasks).Count -eq 0){
      Write-Host "PLAN INVALID"
      Write-Host " - no tasks"
      exit 2
    }

    $state.current_gate="execute"
    Save-MissionState $Root $state "plan-validated"
    Append-Progress $Root "- Plan validation: **PASS**. Task graph dependencies, verification fields, and model routes are coherent."
    Write-Host ("PLAN VALID | tasks={0}" -f @($state.tasks).Count)
  }

  "preflight" {
    $state=Require-Mission

    $task=$null
    if($Id){
      $task=Get-Task $state $Id
    }elseif($state.active_task_id){
      $task=Get-Task $state ([string]$state.active_task_id)
    }else{
      $task=Get-NextReadyTask $state
    }

    $class="balanced"
    $effort="medium"
    if($task){
      if($task.route_class){$class=[string]$task.route_class}
      if($task.effort){$effort=[string]$task.effort}
    }

    $qd=Get-QuotaDecision $state $class $effort -Fresh:$FreshQuota
    $state.quota=$qd.quota

    if($qd.action -eq "STOP"){
      $state.safe_stop_requested=$true
      $state.safe_stop_reason=$qd.reason
      $state.status="paused"
      $state.current_gate="pause"
      $state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "preflight-stop"
      Append-Progress $Root ("- **SAFE STOP** before new work: {0}" -f $qd.reason)
    }elseif($qd.action -eq "CHECKPOINT"){
      [void](Invoke-MissionCheckpoint $Root $state "preflight-quota-pressure")
    }else{
      Save-MissionState $Root $state "preflight-go"
    }

    $taskName="none"
    if($task){$taskName=[string]$task.id}

    $fiveText="unknown"
    if($qd.quota -and $qd.quota.five_hour){
      $fiveText=("{0:N1}%" -f [double]$qd.quota.five_hour.remaining_percent)
    }

    $weekText="unknown"
    if($qd.quota -and $qd.quota.weekly){
      $weekText=("{0:N1}%" -f [double]$qd.quota.weekly.remaining_percent)
    }

    Write-Host ("PREFLIGHT: {0} | task={1} | route={2}/{3} | 5h={4} | weekly={5} | {6}" -f $qd.action,$taskName,$class,$effort,$fiveText,$weekText,$qd.reason)

    if($qd.action -eq "STOP"){exit 3}
  }

  "start-task" {
    $state=Require-Mission
    $v=Validate-MissionPlan $state
    if(!$v.valid){
      throw "Plan is invalid. Run validate and fix the task graph before execution."
    }

    if(!$Id){
      $next=Get-NextReadyTask $state
      if(!$next){throw "No ready task."}
      $Id=[string]$next.id
    }

    $task=Get-Task $state $Id
    if(!$task){throw ("Task not found: {0}" -f $Id)}

    if(!(Test-TaskDependenciesDone $state $task)){
      $depText=Join-List $task.depends_on
      throw ("{0} has incomplete dependencies: {1}" -f $Id,$depText)
    }

    $other=@($state.tasks|Where-Object{$_.status -eq "doing" -and $_.id -ne $Id})
    if($other.Count){
      throw ("Another task is already doing: {0}. Complete/checkpoint it before starting {1}." -f $other[0].id,$Id)
    }

    if($task.status -in @("done","deferred")){
      throw ("{0} cannot be started from status {1}." -f $Id,$task.status)
    }

    $qd=Get-QuotaDecision $state ([string]$task.route_class) ([string]$task.effort) -Fresh:$FreshQuota
    $state.quota=$qd.quota

    if($qd.action -eq "STOP"){
      $state.safe_stop_requested=$true
      $state.safe_stop_reason=$qd.reason
      $state.status="paused"
      $state.current_gate="pause"
      $state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "start-refused-quota"
      Append-Progress $Root ("- Start refused for **{0}**: {1}. Resume file refreshed." -f $Id,$qd.reason)
      Write-Host ("SAFE STOP: refusing to start {0} | {1}" -f $Id,$qd.reason)
      exit 3
    }

    if($qd.action -eq "CHECKPOINT"){
      [void](Invoke-MissionCheckpoint $Root $state "before-task-quota-checkpoint")
    }

    $task.status="doing"
    $task.updated_at=(Get-Date).ToString("o")
    if($ModelUsed){
      $task.model_used=$ModelUsed
    }else{
      $task.model_used="current-lead"
    }

    $state.active_task_id=$task.id
    $state.status="active"
    $state.current_gate="execute"
    $state.safe_stop_requested=$false
    $state.safe_stop_reason=""

    Save-MissionState $Root $state "task-start"
    $entry="- Started **{0}** - {1}`r`n- Planned model: {2} / {3}; actual so far: {4}" -f $Id,$task.title,$task.best_model,$task.effort,$task.model_used
    Append-Progress $Root $entry
    Write-Host ("TASK STARTED: {0} | best_model={1}/{2} | actual={3}" -f $Id,$task.best_model,$task.effort,$task.model_used)
  }

  "progress" {
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}

    $task=$null
    if($Id){$task=Get-Task $state $Id}

    if($task){
      if($ModelUsed){$task.model_used=$ModelUsed}
      if($Message){
        $task.notes=((([string]$task.notes).Trim()+"`r`n"+$Message).Trim())
      }
      $task.updated_at=(Get-Date).ToString("o")
    }

    Save-MissionState $Root $state "progress-update"

    $progressLines=New-Object 'System.Collections.Generic.List[string]'
    $progressTask="mission"
    if($Id){$progressTask=$Id}
    $progressLines.Add(("- Task: **{0}**" -f $progressTask))
    if($Message){$progressLines.Add(("- {0}" -f $Message))}
    if($Verification){$progressLines.Add(("- Verification: {0}" -f $Verification))}
    if($ModelUsed){$progressLines.Add(("- Model used: {0}" -f $ModelUsed))}
    Append-Progress $Root ($progressLines -join "`r`n")
    Write-Host "PROGRESS SAVED"
  }

  "finding" {
    $state=Require-Mission
    if(!$Message){throw "-Message is required."}

    $findingTask="mission"
    if($Id){
      $findingTask=$Id
    }elseif($state.active_task_id){
      $findingTask=[string]$state.active_task_id
    }

    Append-Finding $Root ("- Task: **{0}**`r`n- {1}" -f $findingTask,$Message)
    Save-MissionState $Root $state "finding"
    Write-Host "FINDING SAVED"
  }

  "block-task" {
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}

    $task=Get-Task $state $Id
    if(!$task){throw ("Task not found: {0}" -f $Id)}

    $task.status="blocked"
    $task.block_kind="manual"
    $task.notes=((([string]$task.notes).Trim()+"`r`nBLOCKED: "+$Message).Trim())
    $task.updated_at=(Get-Date).ToString("o")

    if($state.active_task_id -eq $Id){$state.active_task_id=""}

    Save-MissionState $Root $state "task-blocked"
    Append-Progress $Root ("- **{0} BLOCKED** - {1}" -f $Id,$Message)
    Write-Host ("TASK BLOCKED: {0}" -f $Id)
  }

  "complete-task" {
    $state=Require-Mission
    if(!$Id){$Id=[string]$state.active_task_id}

    $task=Get-Task $state $Id
    if(!$task){throw ("Task not found: {0}" -f $Id)}

    if(!(Test-TaskDependenciesDone $state $task)){
      throw ("{0} cannot complete; dependencies are not done." -f $Id)
    }

    if($ModelUsed){$task.model_used=$ModelUsed}
    if($Verification){
      $task.notes=((([string]$task.notes).Trim()+"`r`nVerification: "+$Verification).Trim())
    }
    $task.updated_at=(Get-Date).ToString("o")

    if(!$Verified){
      $task.status="verify"
      $state.current_gate="verify"
      Save-MissionState $Root $state "verification-required"
      $entry="- **{0}** implementation reached verification gate. Not marked done because -Verified was not supplied.`r`n- Evidence: {1}" -f $Id,$Verification
      Append-Progress $Root $entry
      Write-Host ("VERIFY REQUIRED: {0} is not done yet." -f $Id)
      exit 4
    }

    $task.status="done"
    if($state.active_task_id -eq $Id){$state.active_task_id=""}
    Update-ReadyTasks $state
    $state.current_gate="execute"

    $qd=Invoke-MissionCheckpoint $Root $state ("task-complete-"+$Id)
    Append-Progress $Root ("- **{0} DONE** with verification evidence: {1}" -f $Id,$Verification)

    $next=Get-NextReadyTask $state
    $nextId="none"
    if($next){$nextId=[string]$next.id}
    Write-Host ("TASK DONE: {0} | next={1} | quota_action={2}" -f $Id,$nextId,$qd.action)
  }

  "checkpoint" {
    $state=Require-Mission
    $reason="manual-checkpoint"
    if($Message){$reason=$Message}
    $qd=Invoke-MissionCheckpoint $Root $state $reason -FreshQuota:$FreshQuota
    Write-Host ("CHECKPOINT SAVED | quota_action={0} | {1}" -f $qd.action,$qd.reason)
  }

  "pause" {
    $state=Require-Mission
    $pauseReason="manual pause"
    if($Message){$pauseReason=$Message}

    $state.status="paused"
    $state.current_gate="pause"
    $state.safe_stop_requested=$true
    $state.safe_stop_reason=$pauseReason

    [void](Invoke-MissionCheckpoint $Root $state "pause")
    Write-Host ("MISSION PAUSED | {0}" -f $state.safe_stop_reason)
  }

  "resume" {
    $state=Require-Mission
    $state.session_started_at=(Get-Date).ToString("o")

    $qd=Get-QuotaDecision $state "balanced" "medium" -Fresh
    $state.quota=$qd.quota

    if($qd.action -eq "STOP"){
      $state.status="paused"
      $state.current_gate="pause"
      $state.safe_stop_requested=$true
      $state.safe_stop_reason=$qd.reason
      Save-MissionState $Root $state "resume-refused-quota"
      Write-Host ("RESUME REFUSED: {0}" -f $qd.reason)
      Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
      exit 3
    }

    $state.status="active"
    $state.current_gate="execute"
    $state.safe_stop_requested=$false
    $state.safe_stop_reason=""
    Update-ReadyTasks $state
    Save-MissionState $Root $state "resume"
    Append-Progress $Root "- Mission resumed from durable state; session fallback timer reset."
    Write-Host "MISSION RESUMED"
    Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
  }

  "watchdog" {
    $state=Read-MissionState $Root
    if(!$state -or $state.status -eq "done"){exit 0}

    $policy=Get-MissionPolicy
    $qd=Get-QuotaDecision $state "balanced" "medium" -Fresh:$FreshQuota
    $state.quota=$qd.quota

    $age=999
    try{
      $age=((Get-Date)-[DateTimeOffset]::Parse([string]$state.last_checkpoint_at)).TotalMinutes
    }catch{
      $age=999
    }

    if($qd.action -eq "STOP"){
      $state.status="paused"
      $state.current_gate="pause"
      $state.safe_stop_requested=$true
      $state.safe_stop_reason=$qd.reason
      $state.last_checkpoint_at=(Get-Date).ToString("o")
      Save-MissionState $Root $state "watchdog-safe-stop"
      Append-Progress $Root ("- **WATCHDOG SAFE STOP REQUESTED** - {0}" -f $qd.reason)
      if(!$Quiet){Write-Host ("WATCHDOG STOP: {0}" -f $qd.reason)}
    }elseif($age -ge [double]$policy.checkpoint_interval_minutes){
      [void](Invoke-MissionCheckpoint $Root $state "watchdog-periodic")
      if(!$Quiet){Write-Host "WATCHDOG CHECKPOINT"}
    }else{
      Save-MissionState $Root $state "watchdog-refresh"
    }
  }

  "status" {
    $state=Require-Mission
    Update-ReadyTasks $state
    Save-MissionState $Root $state "status"
    $v=Validate-MissionPlan $state

    $counts=@{}
    foreach($s in @("todo","ready","doing","blocked","verify","done","deferred")){
      $counts[$s]=@($state.tasks|Where-Object{$_.status -eq $s}).Count
    }

    Write-Host ("MISSION {0} | status={1} gate={2} active={3}" -f $state.mission_id,$state.status,$state.current_gate,$state.active_task_id)
    Write-Host ("Tasks: ready={0} doing={1} blocked={2} verify={3} done={4} deferred={5}" -f $counts.ready,$counts.doing,$counts.blocked,$counts.verify,$counts.done,$counts.deferred)
    Write-Host ("Plan valid: {0}" -f $v.valid)
    Write-Host (Join-Path (Get-MissionDir $Root) "RESUME-FROM-HERE.md")
  }

  "finish" {
    $state=Require-Mission
    $open=@($state.tasks|Where-Object{$_.status -notin @("done","deferred")})
    if($open.Count){
      $openText=(($open|ForEach-Object{("{0}:{1}" -f $_.id,$_.status)}) -join ", ")
      throw ("Mission cannot finish; open tasks: {0}" -f $openText)
    }

    if(!$Verified){
      throw "Final mission completion requires -Verified and final verification evidence."
    }

    $state.status="done"
    $state.current_gate="done"
    $state.active_task_id=""
    $state.safe_stop_requested=$false
    $state.safe_stop_reason=""
    $state.last_checkpoint_at=(Get-Date).ToString("o")

    Save-MissionState $Root $state "mission-done"
    Append-Progress $Root ("- **MISSION DONE**`r`n- Final verification: {0}" -f $Verification)
    Write-Host "MISSION DONE"
  }
}
