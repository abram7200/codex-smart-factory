param([switch]$Fresh,[switch]$Json)
. (Join-Path $PSScriptRoot "QuotaCommon.ps1")
$q=Get-CodexQuotaSnapshot -Fresh:$Fresh
if($Json){$q|ConvertTo-Json -Depth 10;exit 0}
Write-Host "=== Codex quota snapshot ==="
Write-Host ("Source: {0} | known={1} | stale={2}" -f $q.source,$q.known,$q.stale)
if($null -ne $q.ordinary_usage_allowed){Write-Host ("Ordinary usage allowed: "+$q.ordinary_usage_allowed)}
if($q.rate_limit_reached_type){Write-Host ("Reached type: "+$q.rate_limit_reached_type)}
if($q.five_hour){Write-Host ("5h remaining: {0:N1}% | reset unix={1}" -f $q.five_hour.remaining_percent,$q.five_hour.resets_at)}else{Write-Host "5h remaining: unavailable"}
if($q.weekly){Write-Host ("Weekly remaining: {0:N1}% | reset unix={1}" -f $q.weekly.remaining_percent,$q.weekly.resets_at)}else{Write-Host "Weekly remaining: unavailable"}
