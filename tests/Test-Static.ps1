param([string]$RepoRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference="Stop"
$errors=@()
$ps=Get-ChildItem -LiteralPath $RepoRoot -Recurse -Filter *.ps1 -File
foreach($f in $ps){
  $tok=$null;$err=$null
  [void][Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tok,[ref]$err)
  if($err){foreach($e in $err){$errors+=("$($f.FullName): $($e.Message)")}}
}

$core=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "src\CORE_AGENTS.md")
if($core -notmatch 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'){$errors+="Core marker missing"}
if($core.Length -lt 8000){$errors+="Core unexpectedly small"}
if($core -notmatch 'Check if you are boosted or no\?'){$errors+="Boost protocol missing"}
if($core -notmatch 'Automatic model and reasoning routing'){$errors+="Model router policy missing"}

$common=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "src\runtime\Common.ps1")
if($common -notmatch 'function Save-OriginalGlobalState'){$errors+="Original-state snapshot helper missing"}
if($common -notmatch 'function Restore-GlobalAfterUninstall'){$errors+="Safe uninstall restore helper missing"}
if($common -notmatch 'PRESERVED-GLOBAL:BEGIN'){$errors+="Upgrade preservation logic missing"}

$router=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "src\router\Router.ps1")
$cachePos=$router.IndexOf('models_cache.json')
$onlinePos=$router.IndexOf('debug models 2>$null')
if($cachePos -lt 0 -or $onlinePos -lt 0 -or $cachePos -gt $onlinePos){$errors+="Router is not cache-first"}

$rootCmd=@(Get-ChildItem -LiteralPath $RepoRoot -Filter *.cmd -File)
if($rootCmd.Count -ne 1){$errors+=("Expected exactly one root CMD entrypoint; found "+$rootCmd.Count)}
elseif($rootCmd[0].Name -ne "CODEX_SMART_FACTORY.cmd"){$errors+=("Unexpected root CMD entrypoint: "+$rootCmd[0].Name)}

$launcher=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "CODEX_SMART_FACTORY.cmd")
if($launcher -notmatch ':resolve_powershell'){$errors+="CMD PowerShell resolver missing"}
if($launcher -notmatch 'System32\\WindowsPowerShell\\v1\.0\\powershell\.exe'){$errors+="CMD absolute Windows PowerShell fallback missing"}
if($launcher -notmatch 'goto auto'){$errors+="CMD automatic default flow missing"}
if($launcher -match ':menu'){$errors+="Legacy large interactive menu still present"}

$installer=Get-Content -Raw -LiteralPath (Join-Path $RepoRoot "INSTALL.ps1")
if($installer -notmatch 'function Get-PowerShellHostPath'){$errors+="Installer PowerShell resolver missing"}
if($installer -match 'Start-Process powershell\.exe'){$errors+="Installer still launches bare powershell.exe"}

if($errors.Count){$errors|ForEach-Object{Write-Host $_};exit 1}
Write-Host ("PASS static | ps1="+$ps.Count+" | core chars="+$core.Length+" | root cmd="+$rootCmd[0].Name)
