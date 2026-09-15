. (Join-Path $PSScriptRoot "Common.ps1")
$factory = Get-FactoryHome
$codexHome = Get-CodexHome
$core = Read-Utf8 (Join-Path $factory "src\CORE_AGENTS.md")
if (!$core -or $core -notmatch 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0') {throw "Core file missing or invalid."}
$target = Join-Path $codexHome "AGENTS.override.md"
$preserved = Get-EffectiveGlobalUserText
$parts = New-Object 'Collections.Generic.List[string]'
if (![string]::IsNullOrWhiteSpace($preserved)) {$parts.Add("<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:BEGIN -->`r`n# Preserved pre-existing global Codex instructions`r`n$($preserved.Trim())`r`n<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:END -->")}
$parts.Add($core.Trim())
$new = (($parts -join "`r`n`r`n").Trim() + "`r`n")
$old = Read-Utf8 $target
if ($new -ne $old) {if (Test-Path $target) { [void](Backup-File $target "install-global-core") };Write-Utf8 $target $new;Write-FactoryLog "Installed full global Core to $target"}
Write-Output $target
