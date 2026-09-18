param([string]$RepoRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference="Stop"
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("csf-mission-"+[guid]::NewGuid().ToString("N"))
$codexHome=Join-Path $tmp "home"
$project=Join-Path $tmp "project"
New-Item -ItemType Directory -Force -Path $codexHome,$project|Out-Null
$oldHome=$env:CODEX_HOME
$oldMock=$env:CSF_QUOTA_MOCK_JSON
$env:CODEX_HOME=$codexHome
try{
  New-Item -ItemType Directory -Force -Path (Join-Path $codexHome "smart-factory")|Out-Null
  Copy-Item -Recurse -Force (Join-Path $RepoRoot "src") (Join-Path $codexHome "smart-factory\src")
  $env:CSF_QUOTA_MOCK_JSON='{"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300,"resetsAt":0},"secondary":{"usedPercent":10,"windowDurationMins":10080,"resetsAt":0}},"ordinaryUsageAllowed":true}'
  $mission=Join-Path $codexHome "smart-factory\src\mission\Mission.ps1"

  & $mission init -Root $project -Goal "Regression mission" -Success "All tasks verified" | Out-Null
  & $mission add-task -Root $project -Title "Parent task" -Why "Exercise state transitions" -Scope "src" -Acceptance "parent done" -Verify "parent check" | Out-Null
  & $mission start-task -Root $project -Id T001 | Out-Null

  & $mission discover -Root $project -DiscoveredFrom T001 -Relation blocker -Title "Blocking bug" -Why "Found while implementing parent" -Scope "src" -Acceptance "bug fixed" -Verify "bug check" | Out-Null
  $state=Get-Content -Raw (Join-Path $project ".codex-smart-factory\mission.json")|ConvertFrom-Json
  $parent=@($state.tasks|Where-Object{$_.id -eq "T001"})[0]
  $bug=@($state.tasks|Where-Object{$_.id -eq "T002"})[0]
  if($parent.status -ne "blocked" -or $parent.block_kind -ne "dependency"){throw "dependency blocker state incorrect"}
  if(@($parent.depends_on) -notcontains "T002"){throw "parent missing discovered dependency"}
  if($bug.status -notin @("ready","todo")){throw "discovered blocker not executable"}

  & $mission start-task -Root $project -Id T002 | Out-Null
  & $mission complete-task -Root $project -Id T002 -Verified -Verification "bug check passed" -ModelUsed "test-model" | Out-Null
  $state=Get-Content -Raw (Join-Path $project ".codex-smart-factory\mission.json")|ConvertFrom-Json
  $parent=@($state.tasks|Where-Object{$_.id -eq "T001"})[0]
  if($parent.status -ne "ready"){throw "dependency-blocked parent did not auto-unblock"}

  & $mission start-task -Root $project -Id T001 | Out-Null
  & $mission block-task -Root $project -Id T001 -Message "Waiting for explicit external decision" | Out-Null
  & $mission status -Root $project | Out-Null
  $state=Get-Content -Raw (Join-Path $project ".codex-smart-factory\mission.json")|ConvertFrom-Json
  $parent=@($state.tasks|Where-Object{$_.id -eq "T001"})[0]
  if($parent.status -ne "blocked" -or $parent.block_kind -ne "manual"){throw "manual blocker was incorrectly auto-unblocked"}

  $env:CSF_QUOTA_MOCK_JSON='{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":300,"resetsAt":0},"secondary":{"usedPercent":100,"windowDurationMins":10080,"resetsAt":0}},"ordinaryUsageAllowed":false}'
  & $mission preflight -Root $project -FreshQuota
  if($LASTEXITCODE -eq 3){throw "Smart Factory must not impose a local STOP when included quota is exhausted"}
  if(!(Test-Path (Join-Path $project ".codex-smart-factory\RESUME-FROM-HERE.md"))){throw "resume file missing after quota checkpoint"}
  $state=Get-Content -Raw (Join-Path $project ".codex-smart-factory\mission.json")|ConvertFrom-Json
  if($state.status -eq "paused"){throw "quota checkpoint incorrectly paused the mission"}

  Write-Host "PASS mission task graph / discovery / sticky blocker / credit-compatible quota checkpoint"
}finally{
  if($null -eq $oldHome){Remove-Item Env:\CODEX_HOME -ErrorAction SilentlyContinue}else{$env:CODEX_HOME=$oldHome}
  if($null -eq $oldMock){Remove-Item Env:\CSF_QUOTA_MOCK_JSON -ErrorAction SilentlyContinue}else{$env:CSF_QUOTA_MOCK_JSON=$oldMock}
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
