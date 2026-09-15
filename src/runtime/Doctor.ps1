param([string]$Cwd=(Get-Location).Path)
. (Join-Path $PSScriptRoot "Common.ps1")
$factory=Get-FactoryHome
Write-Host "=== Codex Smart Factory Doctor ==="
& (Join-Path $factory "src\runtime\Status.ps1") -Cwd $Cwd
Write-Host ""
Write-Host ("Factory home: " + $factory)
Write-Host ("Core bytes: " + (Get-Item (Join-Path $factory "src\CORE_AGENTS.md")).Length)
Write-Host ("Registered projects: " + @(Get-ProjectRegistry).Count)
Write-Host ("Old project scan report: " + $(if(Test-Path (Join-Path $factory "state\OLD_PROJECT_SCAN.txt")){"OK"}else{"MISSING"}))
Write-Host ""
& (Join-Path $factory "src\router\Router-Status.ps1")
Write-Host ""
& (Join-Path $factory "src\mission\Quota.ps1")
Write-Host ""
$root=Get-ProjectRoot $Cwd
if($root -and (Test-Path -LiteralPath (Join-Path $root ".codex-smart-factory\mission.json"))){
  & (Join-Path $factory "src\mission\Mission.ps1") status -Root $root
}else{
  Write-Host "Mission: no active mission for this health-check target (runtime is installed)."
}
