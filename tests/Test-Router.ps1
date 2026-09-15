param([string]$RepoRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference="Stop"
$tmp=Join-Path ([IO.Path]::GetTempPath()) ("csf-router-"+[guid]::NewGuid().ToString("N"));New-Item -ItemType Directory -Force -Path $tmp|Out-Null;$old=$env:CODEX_HOME;$env:CODEX_HOME=$tmp
try{
  New-Item -ItemType Directory -Force -Path (Join-Path $tmp "smart-factory\state")|Out-Null;Copy-Item -Recurse -Force (Join-Path $RepoRoot "src") (Join-Path $tmp "smart-factory\src")
  $catalog=[ordered]@{models=@([ordered]@{slug="gpt-5.6-luna";display_name="Luna";visibility="list";priority=4;supported_reasoning_levels=@("low","medium","high","xhigh","max");default_reasoning_level="medium"},[ordered]@{slug="gpt-5.6-terra";display_name="Terra";visibility="list";priority=3;supported_reasoning_levels=@("low","medium","high","xhigh","max");default_reasoning_level="medium"},[ordered]@{slug="gpt-5.6-sol";display_name="Sol";visibility="list";priority=2;supported_reasoning_levels=@("low","medium","high","xhigh","max");default_reasoning_level="medium"},[ordered]@{slug="gpt-6-astra";display_name="Astra";visibility="list";priority=1;supported_reasoning_levels=@("low","medium","high","xhigh","max");default_reasoning_level="medium"},[ordered]@{slug="codex-auto-review";display_name="Internal";visibility="hide";priority=0;supported_reasoning_levels=@("medium")})}
  $catalog|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 (Join-Path $tmp "models_cache.json")
  . (Join-Path $tmp "smart-factory\src\router\Router.ps1")
  $a=Resolve-Route "Fix a typo in README";$b=Resolve-Route "Design production authentication migration with rollback, concurrency and data-loss risk"
  if($a.score -ge $b.score){throw "Complexity ordering failed"};if($a.model -eq "codex-auto-review" -or $b.model -eq "codex-auto-review"){throw "Hidden model selected"};if($b.route_class -notin @("strong","frontier")){throw "High-risk task did not escalate"}
  Write-Host ("PASS router | simple="+$a.route_class+"/"+$a.model+" hard="+$b.route_class+"/"+$b.model)
}finally{if($null -eq $old){Remove-Item Env:\CODEX_HOME -ErrorAction SilentlyContinue}else{$env:CODEX_HOME=$old};Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue}
