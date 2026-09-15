Set-StrictMode -Version 2.0

function Get-CodexHome {
  if ($env:CODEX_HOME) { return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:CODEX_HOME)) }
  return [IO.Path]::GetFullPath((Join-Path $HOME ".codex"))
}
function Get-FactoryHome { Join-Path (Get-CodexHome) "smart-factory" }
function Read-Utf8([string]$Path) { if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }; [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
function Write-Utf8([string]$Path, [string]$Text) { $parent=Split-Path -Parent $Path;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }
function Get-ShortHash([string]$Text) {$sha=[Security.Cryptography.SHA256]::Create();try{$bytes=[Text.Encoding]::UTF8.GetBytes($Text);$hash=$sha.ComputeHash($bytes);([BitConverter]::ToString($hash).Replace("-","").Substring(0,20).ToLowerInvariant())}finally{$sha.Dispose()}}
function Write-FactoryLog([string]$Message){try{$dir=Join-Path (Get-FactoryHome) "logs";New-Item -ItemType Directory -Force -Path $dir|Out-Null;$path=Join-Path $dir "factory.log";if((Test-Path $path)-and(Get-Item $path).Length -gt 3MB){Move-Item -Force $path (Join-Path $dir ("factory-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log"))};Add-Content -Encoding UTF8 -Path $path -Value ("[{0}] {1}" -f (Get-Date -Format "s"),$Message)}catch{}}
function Backup-File([string]$Path,[string]$Reason="edit"){if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$root=Join-Path (Get-FactoryHome) "backups";$batch=Join-Path $root (Get-Date -Format "yyyyMMdd-HHmmss-fff");New-Item -ItemType Directory -Force -Path $batch|Out-Null;$dest=Join-Path $batch ((Get-ShortHash $Path)+"-"+[IO.Path]::GetFileName($Path));Copy-Item -LiteralPath $Path -Destination $dest -Force;([ordered]@{time=(Get-Date).ToString("o");reason=$Reason;original=$Path;backup=$dest}|ConvertTo-Json -Compress)|Add-Content -Encoding UTF8 (Join-Path $batch "manifest.jsonl");$dest}

function Remove-CSFManagedBlocks([string]$Text){
  $patterns=@('<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:BEGIN -->.*?<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:END -->','<!-- CODEX-SMART-FACTORY:CORE:BEGIN -->.*?<!-- CODEX-SMART-FACTORY:CORE:END -->','<!-- BEGIN CODEX-SMART-INJECTOR v2 -->.*?<!-- END CODEX-SMART-INJECTOR v2 -->','<!-- BEGIN CODEX-SMART-INJECTOR v3 -->.*?<!-- END CODEX-SMART-INJECTOR v3 -->','<!-- BEGIN CODEX-SMART-FACTORY.*?-->.*?<!-- END CODEX-SMART-FACTORY.*?-->','<!-- BEGIN CODEX-SMART-FACTORY MIRROR v[0-9]+ -->.*?<!-- END CODEX-SMART-FACTORY MIRROR v[0-9]+ -->')
  foreach($p in $patterns){$Text=[regex]::Replace($Text,$p,"",[Text.RegularExpressions.RegexOptions]::Singleline)}
  $Text.Trim()
}

function Get-EffectiveGlobalUserText {
  $home=Get-CodexHome;$override=Join-Path $home "AGENTS.override.md";$base=Join-Path $home "AGENTS.md"
  if(Test-Path -LiteralPath $override -PathType Leaf){
    $raw=Read-Utf8 $override;$isManaged=$raw -match 'CODEX-SMART-FACTORY:CORE:BEGIN'
    if(!$isManaged){return Remove-CSFManagedBlocks $raw}
    $parts=New-Object 'Collections.Generic.List[string]';$state=Get-OriginalGlobalState
    if($state -and ![bool]$state.override_existed){
      if(Test-Path -LiteralPath $base -PathType Leaf){$baseText=Remove-CSFManagedBlocks (Read-Utf8 $base);if(![string]::IsNullOrWhiteSpace($baseText)){$parts.Add($baseText.Trim())}}
    }else{
      $m=[regex]::Match($raw,'<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:BEGIN -->\s*# Preserved pre-existing global Codex instructions\s*(.*?)\s*<!-- CODEX-SMART-FACTORY:PRESERVED-GLOBAL:END -->',[Text.RegularExpressions.RegexOptions]::Singleline)
      if($m.Success -and ![string]::IsNullOrWhiteSpace($m.Groups[1].Value)){$parts.Add($m.Groups[1].Value.Trim())}
    }
    $outside=Remove-CSFManagedBlocks $raw
    if(![string]::IsNullOrWhiteSpace($outside)){$parts.Add($outside.Trim())}
    if($parts.Count){return (($parts|Select-Object -Unique)-join "`r`n`r`n")}
    return ""
  }
  if(Test-Path -LiteralPath $base -PathType Leaf){return Remove-CSFManagedBlocks (Read-Utf8 $base)}
  return ""
}

function Save-OriginalGlobalState {
  $factory=Get-FactoryHome;$stateDir=Join-Path $factory "state";New-Item -ItemType Directory -Force -Path $stateDir|Out-Null;$path=Join-Path $stateDir "original-global-state.json"
  if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
  $home=Get-CodexHome;$override=Join-Path $home "AGENTS.override.md";$exists=Test-Path -LiteralPath $override -PathType Leaf;$bytes=if($exists){[IO.File]::ReadAllBytes($override)}else{$null}
  $obj=[ordered]@{version=2;captured_at=(Get-Date).ToString("o");override_existed=$exists;original_override_base64=if($bytes){[Convert]::ToBase64String($bytes)}else{$null}}
  Write-Utf8 $path ($obj|ConvertTo-Json -Depth 4);Write-FactoryLog "Captured original override existence/content for safe uninstall.";return $path
}
function Get-OriginalGlobalState {$path=Join-Path (Get-FactoryHome) "state\original-global-state.json";if(!(Test-Path -LiteralPath $path -PathType Leaf)){return $null};try{return(Get-Content -Raw -LiteralPath $path|ConvertFrom-Json)}catch{return $null}}

function Restore-GlobalAfterUninstall {
  $home=Get-CodexHome;$override=Join-Path $home "AGENTS.override.md";$statePath=Join-Path (Get-FactoryHome) "state\original-global-state.json";$state=Get-OriginalGlobalState;if(!$state){return $false}
  $raw=Read-Utf8 $override;$outside=if($raw){Remove-CSFManagedBlocks $raw}else{""}
  if([bool]$state.override_existed){
    $userText=Get-EffectiveGlobalUserText
    if(![string]::IsNullOrWhiteSpace($userText)){Write-Utf8 $override ($userText.TrimEnd()+"`r`n")}elseif($state.original_override_base64){[IO.File]::WriteAllBytes($override,[Convert]::FromBase64String([string]$state.original_override_base64))}else{Remove-Item -LiteralPath $override -Force -ErrorAction SilentlyContinue}
  }else{
    if(![string]::IsNullOrWhiteSpace($outside)){
      $parts=New-Object 'Collections.Generic.List[string]';$base=Join-Path $home "AGENTS.md"
      if(Test-Path -LiteralPath $base -PathType Leaf){$baseText=Remove-CSFManagedBlocks (Read-Utf8 $base);if(![string]::IsNullOrWhiteSpace($baseText)){$parts.Add($baseText.Trim())}}
      $parts.Add($outside.Trim());Write-Utf8 $override ((($parts|Select-Object -Unique)-join "`r`n`r`n").TrimEnd()+"`r`n")
    }else{Remove-Item -LiteralPath $override -Force -ErrorAction SilentlyContinue}
  }
  Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue;Write-FactoryLog "Removed Smart Factory global layer without rolling back user instructions.";return $true
}

function Get-ProjectRoot([string]$Cwd){
  if(!(Test-Path -LiteralPath $Cwd -PathType Container)){return $null};try{$dir=(Get-Item -LiteralPath $Cwd).FullName}catch{return $null}
  $codex=Get-CodexHome;if($dir.StartsWith($codex,[StringComparison]::OrdinalIgnoreCase)){return $null};if($env:WINDIR -and $dir.StartsWith($env:WINDIR,[StringComparison]::OrdinalIgnoreCase)){return $null}
  $p=Get-Item -LiteralPath $dir;while($p){if(Test-Path -LiteralPath (Join-Path $p.FullName ".git")){return $p.FullName};$p=$p.Parent}
  $markers=@("package.json","pyproject.toml","requirements.txt","Cargo.toml","go.mod","pom.xml","build.gradle","build.gradle.kts","CMakeLists.txt","composer.json","Gemfile","mix.exs","pubspec.yaml","Dockerfile")
  $p=Get-Item -LiteralPath $dir;while($p){foreach($m in $markers){if(Test-Path -LiteralPath (Join-Path $p.FullName $m)){return $p.FullName}};if(Get-ChildItem -LiteralPath $p.FullName -Filter *.sln -File -ErrorAction SilentlyContinue|Select-Object -First 1){return $p.FullName};$p=$p.Parent}
  $h=[IO.Path]::GetFullPath($HOME);$drive=[IO.Path]::GetPathRoot($dir);if($dir -ne $h -and $dir -ne $drive){return $dir};return $null
}

function Read-FileSlices([string]$Path,[int]$HeadBytes=524288,[int]$TailBytes=131072){if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return ""};try{$fs=New-Object IO.FileStream($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$len=$fs.Length;$enc=New-Object Text.UTF8Encoding($false,$false);$take=[Math]::Min([int64]$HeadBytes,$len);$buf=New-Object byte[] $take;[void]$fs.Read($buf,0,$take);$head=$enc.GetString($buf);if($len -le $HeadBytes){return $head};$take2=[Math]::Min([int64]$TailBytes,$len);[void]$fs.Seek(-$take2,[IO.SeekOrigin]::End);$buf2=New-Object byte[] $take2;[void]$fs.Read($buf2,0,$take2);return $head+"`n"+$enc.GetString($buf2)}finally{$fs.Dispose()}}catch{return ""}}
function Get-CwdsFromRollout([string]$Path){$text=Read-FileSlices $Path;$set=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase);if(!$text){return @()};foreach($m in [regex]::Matches($text,'"cwd"\s*:\s*(?<q>"(?:\\.|[^"\\])*")')){try{$obj=('{"v":'+$m.Groups["q"].Value+'}')|ConvertFrom-Json;$v=[string]$obj.v;if($v -and (Test-Path -LiteralPath $v -PathType Container)){[void]$set.Add((Get-Item -LiteralPath $v).FullName)}}catch{}};foreach($m in [regex]::Matches($text,'<cwd>(?<p>[^<\r\n]+)</cwd>')){$v=$m.Groups["p"].Value;if($v -and (Test-Path -LiteralPath $v -PathType Container)){[void]$set.Add((Get-Item -LiteralPath $v).FullName)}};@($set)}
function Get-ProjectRegistry {$dir=Join-Path (Get-FactoryHome) "state\projects";if(!(Test-Path $dir)){return @()};$out=@();foreach($f in Get-ChildItem -LiteralPath $dir -Filter *.json -File -ErrorAction SilentlyContinue){try{$out+=(Get-Content -Raw -LiteralPath $f.FullName|ConvertFrom-Json)}catch{}};$out}
function Save-ProjectRegistry([string]$Root,[string]$Cwd,[string]$Source="session"){$dir=Join-Path (Get-FactoryHome) "state\projects";New-Item -ItemType Directory -Force -Path $dir|Out-Null;$id=Get-ShortHash $Root;$obj=[ordered]@{id=$id;root=$Root;last_cwd=$Cwd;source=$Source;last_seen=(Get-Date).ToString("o")};Write-Utf8 (Join-Path $dir "$id.json") ($obj|ConvertTo-Json -Depth 4)}
function Add-GitLocalExclude([string]$Root,[string]$RelativePath){$git=Join-Path $Root ".git";if(!(Test-Path -LiteralPath $git -PathType Container)){return};$info=Join-Path $git "info";New-Item -ItemType Directory -Force -Path $info|Out-Null;$exclude=Join-Path $info "exclude";$line="/"+($RelativePath -replace "\\","/").TrimStart('/');$text=Read-Utf8 $exclude;$escaped=[regex]::Escape($line);if($text -notmatch ("(?m)^"+$escaped+"\s*$")){if(Test-Path $exclude){[void](Backup-File $exclude "git-local-exclude")};$new=if([string]::IsNullOrWhiteSpace($text)){$line+"`r`n"}else{$text.TrimEnd()+"`r`n"+$line+"`r`n"};Write-Utf8 $exclude $new}}
