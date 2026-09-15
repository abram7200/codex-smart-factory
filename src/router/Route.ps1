param(
  [Parameter(Mandatory=$true)][string]$Task,
  [string]$CurrentModel="",
  [switch]$Json
)
. (Join-Path $PSScriptRoot "Router.ps1")
$d = Resolve-Route $Task $CurrentModel
if ($Json) {$d | ConvertTo-Json -Depth 6}
else {
  Write-Output ("ROUTE: {0} | model={1} | effort={2} | action={3} | profile={4}" -f
    $d.route_class.ToUpper(), $(if($d.model){$d.model}else{"LOCAL"}), $d.effort, $d.action, $d.profile)
  Write-Output ("Reason: " + $d.reason)
  if ($d.signals.Count) { Write-Output ("Signals: " + ($d.signals -join ", ")) }
}
