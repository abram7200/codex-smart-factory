param([Parameter(Mandatory=$true)][string]$Root)
. (Join-Path $PSScriptRoot "Common.ps1")
try { $Root = (Get-Item -LiteralPath $Root).FullName } catch { exit 0 }
$factory=Get-FactoryHome;$profiles=Join-Path $factory "state\profiles";New-Item -ItemType Directory -Force -Path $profiles|Out-Null;$id=Get-ShortHash $Root;$path=Join-Path $profiles "$id.json"
$markers=@("package.json","pyproject.toml","requirements.txt","Cargo.toml","go.mod","pom.xml","build.gradle","build.gradle.kts","CMakeLists.txt","composer.json","Gemfile","mix.exs","pubspec.yaml","Dockerfile","docker-compose.yml","compose.yml","tsconfig.json","pytest.ini","tox.ini","ruff.toml")
$keyFiles=@();foreach($m in $markers){if(Test-Path -LiteralPath (Join-Path $Root $m) -PathType Leaf){$keyFiles+=$m}}
$sln=@(Get-ChildItem -LiteralPath $Root -Filter *.sln -File -ErrorAction SilentlyContinue|ForEach-Object{$_.Name});$csproj=@(Get-ChildItem -LiteralPath $Root -Filter *.csproj -File -ErrorAction SilentlyContinue|ForEach-Object{$_.Name})
$stack=New-Object 'Collections.Generic.List[string]';$commands=New-Object 'Collections.Generic.List[string]';$pkg=Join-Path $Root "package.json"
if(Test-Path $pkg){try{$j=Get-Content -Raw -LiteralPath $pkg|ConvertFrom-Json;$stack.Add("node");if($j.scripts){foreach($p in $j.scripts.PSObject.Properties){$commands.Add("npm run $($p.Name) => $($p.Value)")}}}catch{}}
if(Test-Path (Join-Path $Root "pyproject.toml")){$stack.Add("python")}elseif(Test-Path (Join-Path $Root "requirements.txt")){$stack.Add("python")}
if(Test-Path (Join-Path $Root "Cargo.toml")){$stack.Add("rust")};if(Test-Path (Join-Path $Root "go.mod")){$stack.Add("go")};if(Test-Path (Join-Path $Root "pom.xml")){$stack.Add("java-maven")};if((Test-Path (Join-Path $Root "build.gradle"))-or(Test-Path (Join-Path $Root "build.gradle.kts"))){$stack.Add("gradle")};if($sln.Count -or $csproj.Count){$stack.Add("dotnet")};if(Test-Path (Join-Path $Root "Dockerfile")){$stack.Add("docker")}
$agents=@();foreach($name in @("AGENTS.override.md","AGENTS.md")){$f=Join-Path $Root $name;if(Test-Path $f){$agents+=$name}}
$obj=[ordered]@{version=1;root=$Root;last_profiled=(Get-Date).ToString("o");stack=@($stack|Select-Object -Unique);key_files=@($keyFiles+$sln+$csproj);root_instruction_files=$agents;evidence_commands=@($commands)}
$new=$obj|ConvertTo-Json -Depth 8;$old=Read-Utf8 $path;if($new -ne $old){Write-Utf8 $path $new};Write-Output $path
