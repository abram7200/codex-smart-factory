param([string]$PackageRoot=$PSScriptRoot)
$ErrorActionPreference="Stop"
$bad=@()
$files=Get-ChildItem -LiteralPath $PackageRoot -Recurse -Filter *.ps1 -File
foreach($f in $files){
  $tokens=$null;$errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
  if($errors -and $errors.Count){foreach($e in $errors){$bad+=("$($f.FullName): $($e.Message)")}}
}
$core=Join-Path $PackageRoot "src\CORE_AGENTS.md"
if(!(Test-Path $core)){$bad+="CORE_AGENTS.md missing"}
elseif((Get-Content -Raw -LiteralPath $core) -notmatch 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'){$bad+="Core ID missing"}
if($bad.Count){
  Write-Host "PRECHECK FAILED" -ForegroundColor Red
  $bad|ForEach-Object{Write-Host $_}
  throw "PRECHECK FAILED: $($bad.Count) validation error(s)."
}
Write-Host ("PRECHECK PASS | PowerShell scripts="+$files.Count+" | core bytes="+(Get-Item $core).Length) -ForegroundColor Green
