. (Join-Path $PSScriptRoot "Router.ps1")
$cfg = Get-RouterConfig
$cat = Normalize-Catalog (Get-ModelCatalog)
Write-Host "=== Codex Smart Factory Router ==="
Write-Host ("Profile: " + $cfg.profile)
Write-Host ("Visible usable catalog entries: " + @($cat).Count)
foreach ($m in $cat) {
  Write-Host (" - {0} | efforts={1} | default={2}" -f $m.slug, $(if($m.efforts.Count){$m.efforts -join ","}else{"unknown"}), $m.default_effort)
}
