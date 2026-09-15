param([Parameter(Mandatory=$true)][ValidateSet("token-saver","balanced","max-quality")][string]$Profile)
. (Join-Path $PSScriptRoot "Router.ps1")
$path = Set-RouterProfile $Profile
Write-Host "[OK] Router profile: $Profile"
Write-Host "Config: $path"
