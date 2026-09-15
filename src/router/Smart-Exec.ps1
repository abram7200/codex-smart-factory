param(
  [Parameter(Mandatory=$true)][string]$Task,
  [string]$Cwd=(Get-Location).Path,
  [string]$TaskId="",
  [switch]$DryRun
)
. (Join-Path $PSScriptRoot "Router.ps1")

if ($env:CSF_ROUTED_CHILD -eq "1") { throw "Recursive Smart Factory routing is disabled." }
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (!$codex) {$codex = Get-Command codex.cmd -ErrorAction SilentlyContinue}
if (!$codex) { throw "Codex CLI is not in PATH." }
$root = Get-ProjectRoot $Cwd
if (!$root) {$root=$Cwd}
$factory=Get-FactoryHome
$missionScript=Join-Path $factory "src\mission\Mission.ps1"
$missionPath=Join-Path $root ".codex-smart-factory\mission.json"
$hasMission=Test-Path -LiteralPath $missionPath -PathType Leaf

if($hasMission){
  $preArgs=@("preflight","-Root",$root,"-FreshQuota")
  if($TaskId){$preArgs+=@("-Id",$TaskId)}
  & $missionScript @preArgs
  if($LASTEXITCODE -eq 3){throw "Mission preflight requested SAFE STOP; routed worker was not started."}
}

$d = Resolve-Route $Task
$sandbox = if ($d.write_task) {"workspace-write"} else {"read-only"}
$leaf = @"
[Codex Smart Factory routed leaf]
You are a bounded worker inside one Mission Control task.
Do not create another Smart Factory routed worker.
Follow the installed global Smart Factory Core and all applicable project instructions.
Do not silently expand scope. If you discover a blocker, required edit, bug, regression, or follow-up outside the assignment, return it in the structured discoveries array.
Work only on the assignment. Report exact verification actually run. If verification was not run, say so.
Assignment:
$Task
"@

$schemaPath=Join-Path $factory "src\router\worker-output.schema.json"
$help="";try{$help=(& $codex.Source exec --help 2>&1|Out-String)}catch{}
$supportsStructured=($help -match '--output-schema') -and ($help -match '--output-last-message') -and (Test-Path $schemaPath)
$resultDir=if($hasMission){Join-Path $root ".codex-smart-factory\worker-results"}else{Join-Path $factory "state\worker-results"}
New-Item -ItemType Directory -Force -Path $resultDir|Out-Null
$resultFile=Join-Path $resultDir ((if($TaskId){$TaskId}else{"worker"})+"-"+(Get-Date -Format "yyyyMMdd-HHmmss-fff")+".json")
$args=@("exec")
if($d.model){$args+=@("--model",[string]$d.model,"--config",("model_reasoning_effort=`""+[string]$d.effort+"`""))}
$args+=@("--config",'approval_policy="never"',"--sandbox",$sandbox,"--cd",$root,"--skip-git-repo-check")
if($supportsStructured){$args+=@("--output-schema",$schemaPath,"--output-last-message",$resultFile)}
$args+=@($leaf)

Write-Host ("SMART EXEC | model={0} effort={1} route={2} sandbox={3} structured={4}" -f $(if($d.model){$d.model}else{"Codex-default"}),$d.effort,$d.route_class,$sandbox,$supportsStructured)
if ($DryRun) {Write-Host ("Command: " + $codex.Source + " " + (($args | ForEach-Object {"[" + $_ + "]"}) -join " "));exit 0}
$actualModel=if($d.model){[string]$d.model}else{"Codex-default"}
if($hasMission -and $TaskId){& $missionScript progress -Root $root -Id $TaskId -Message "Exact-model routed worker started." -ModelUsed $actualModel | Out-Null}
$old = $env:CSF_ROUTED_CHILD;$env:CSF_ROUTED_CHILD="1"
try {
  & $codex.Source @args;$code=$LASTEXITCODE
  if($hasMission -and $TaskId){
    if($supportsStructured -and (Test-Path -LiteralPath $resultFile -PathType Leaf)){
      try{
        $result=Get-Content -Raw -LiteralPath $resultFile|ConvertFrom-Json
        $msg="Routed worker exited code $code. Summary: $($result.summary)";if($result.verification){$msg+=" Verification: $($result.verification)"};if($result.uncertainty){$msg+=" Uncertainty: $($result.uncertainty)"}
        & $missionScript progress -Root $root -Id $TaskId -Message $msg -ModelUsed $actualModel | Out-Null
        foreach($disc in @($result.discoveries)){
          if(!$disc.title -or !$disc.why -or !$disc.relation){continue}
          try{& $missionScript discover -Root $root -DiscoveredFrom $TaskId -Relation ([string]$disc.relation) -Title ([string]$disc.title) -Why ([string]$disc.why) -Scope ([string]$disc.scope) -Acceptance ([string]$disc.acceptance) -Verify ([string]$disc.verify) -Risk ([string]$disc.risk) | Out-Null;Write-Host ("AUTO-DISCOVERY -> mission task: {0} [{1}]" -f $disc.title,$disc.relation)}catch{& $missionScript finding -Root $root -Id $TaskId -Message ("Worker discovery could not be auto-registered: "+$disc.title+" :: "+$_.Exception.Message) | Out-Null}
        }
      }catch{& $missionScript progress -Root $root -Id $TaskId -Message ("Routed worker exited code "+$code+"; structured result parse failed: "+$_.Exception.Message) -ModelUsed $actualModel | Out-Null}
    }else{& $missionScript progress -Root $root -Id $TaskId -Message ("Routed worker exited with code "+$code+". Structured discovery ingestion unavailable; lead must inspect result and register discoveries before scope expansion.") -ModelUsed $actualModel | Out-Null}
  }
  exit $code
} finally {
  if ($null -eq $old) { Remove-Item Env:\CSF_ROUTED_CHILD -ErrorAction SilentlyContinue }
  else {$env:CSF_ROUTED_CHILD=$old}
}
