param([switch]$Quiet)
. (Join-Path $PSScriptRoot "Common.ps1")
$codexHome=Get-CodexHome;$factory=Get-FactoryHome;$dict=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase);$files=@()
try{$files=Get-ChildItem -LiteralPath $codexHome -Recurse -Filter *.jsonl -File -ErrorAction SilentlyContinue|Where-Object{$_.FullName -notlike "$factory*"}|Sort-Object LastWriteTime -Descending}catch{}
foreach($f in $files){foreach($cwd in Get-CwdsFromRollout $f.FullName){$root=Get-ProjectRoot $cwd;if($root -and !$dict.ContainsKey($root)){$dict[$root]=$cwd}}}
foreach($p in Get-ProjectRegistry){if($p.root -and (Test-Path -LiteralPath $p.root -PathType Container)){if(!$dict.ContainsKey([string]$p.root)){$dict[[string]$p.root]=if($p.last_cwd){[string]$p.last_cwd}else{[string]$p.root}}}}
$report=New-Object 'Collections.Generic.List[string]';foreach($kv in $dict.GetEnumerator()){try{Save-ProjectRegistry $kv.Key $kv.Value "history";& (Join-Path $factory "src\runtime\Profile-Project.ps1") -Root $kv.Key|Out-Null;$report.Add("[OK] "+$kv.Key)}catch{$report.Add("[FAIL] "+$kv.Key+" :: "+$_.Exception.Message)}}
$reportPath=Join-Path $factory "state\OLD_PROJECT_SCAN.txt";Write-Utf8 $reportPath (("Codex Smart Factory old-project scan "+(Get-Date).ToString("o")+"`r`n")+($report -join "`r`n")+"`r`n")
if(!$Quiet){Write-Host ("Old/current projects discovered: "+$dict.Count);foreach($k in ($dict.Keys|Sort-Object)){Write-Host " - $k"};Write-Host "Report: $reportPath"};@($dict.Keys)
