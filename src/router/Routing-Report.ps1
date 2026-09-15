param([int]$Last=200)
. (Join-Path $PSScriptRoot "Router.ps1")
$path = Join-Path (Get-FactoryHome) "state\routing-ledger.jsonl"
if (!(Test-Path $path)) {Write-Host "No routing decisions recorded yet."; exit 0}
$items=@();foreach($line in Get-Content -LiteralPath $path -Tail $Last){try {$items += ($line | ConvertFrom-Json)} catch {}}
Write-Host ("Decisions: " + $items.Count)
foreach($label in @("class","model","action")){Write-Host ("By " + $label + ":");$items | Group-Object $label | Sort-Object Count -Descending | ForEach-Object {Write-Host (" - {0}: {1}" -f $(if($_.Name){$_.Name}else{"LOCAL"}),$_.Count)}}
