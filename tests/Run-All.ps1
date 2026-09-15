$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot "Test-Static.ps1") -RepoRoot $root
& (Join-Path $PSScriptRoot "Test-Router.ps1") -RepoRoot $root
& (Join-Path $PSScriptRoot "Test-Install.ps1") -RepoRoot $root
& (Join-Path $PSScriptRoot "Test-Mission.ps1") -RepoRoot $root
Write-Host "ALL TESTS PASSED"
$global:LASTEXITCODE=0
exit 0
