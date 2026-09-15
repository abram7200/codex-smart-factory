param([string]$RepoRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference="Stop"
$old=$env:CODEX_HOME

function Invoke-Scenario([string]$Name,[scriptblock]$Arrange,[scriptblock]$AssertAfterUninstall){
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ("csf-test-"+[guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  $env:CODEX_HOME=$tmp
  try{
    & $Arrange $tmp
    $beforeBase=if(Test-Path (Join-Path $tmp "AGENTS.md")){[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $tmp "AGENTS.md")))}else{$null}
    $beforeOver=if(Test-Path (Join-Path $tmp "AGENTS.override.md")){[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $tmp "AGENTS.override.md")))}else{$null}

    & (Join-Path $RepoRoot "INSTALL.ps1") install -NoAutostart | Out-Null
    $installed=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.override.md")
    if($installed -notmatch 'CSF_CORE_ID=codex-smart-factory-final-1\.1\.0'){throw "${Name}: Core not installed"}

    # Regression: update/reinstall must keep pre-existing global instructions.
    & (Join-Path $RepoRoot "INSTALL.ps1") install -NoAutostart | Out-Null
    $reinstalled=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.override.md")
    if($Name -eq "AGENTS only" -and $reinstalled -notmatch 'USER BASE RULE'){throw "${Name}: user rule lost on reinstall"}
    if($Name -eq "pre-existing override" -and $reinstalled -notmatch 'ORIGINAL OVERRIDE'){throw "${Name}: override rule lost on reinstall"}

    # Simulate user edits while Smart Factory is installed. AGENTS.md must never be rolled back.
    if($Name -eq "AGENTS only"){
      [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.md"),"USER BASE RULE UPDATED AFTER INSTALL`r`n",(New-Object Text.UTF8Encoding($false)))
    }
    if($Name -eq "generated override with user addition"){
      Add-Content -Encoding UTF8 -LiteralPath (Join-Path $tmp "AGENTS.override.md") -Value "USER ADDED TO GENERATED OVERRIDE"
    }
    if($Name -eq "pre-existing override"){
      Add-Content -Encoding UTF8 -LiteralPath (Join-Path $tmp "AGENTS.override.md") -Value "USER ADDED DURING INSTALL"
    }

    & (Join-Path $RepoRoot "INSTALL.ps1") uninstall | Out-Null

    $afterBase=if(Test-Path (Join-Path $tmp "AGENTS.md")){[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $tmp "AGENTS.md")))}else{$null}
    $afterOver=if(Test-Path (Join-Path $tmp "AGENTS.override.md")){[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $tmp "AGENTS.override.md")))}else{$null}
    if($Name -ne "AGENTS only" -and $beforeBase -ne $afterBase){throw "${Name}: AGENTS.md changed unexpectedly"}
    if($Name -ne "generated override with user addition" -and $beforeOver -ne $afterOver){throw "${Name}: AGENTS.override.md changed unexpectedly"}
    & $AssertAfterUninstall $tmp
    Write-Host "PASS install/uninstall: $Name"
  }finally{
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  }
}

try{
  Invoke-Scenario "empty" { param($tmp) } {
    param($tmp)
    if(Test-Path (Join-Path $tmp "AGENTS.override.md")){throw "empty: override should not remain"}
  }

  Invoke-Scenario "AGENTS only" {
    param($tmp)
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.md"),"USER BASE RULE`r`n",(New-Object Text.UTF8Encoding($false)))
  } {
    param($tmp)
    if(Test-Path (Join-Path $tmp "AGENTS.override.md")){throw "AGENTS only: generated override should have been removed"}
    $base=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.md")
    if($base -notmatch 'UPDATED AFTER INSTALL'){throw "AGENTS only: user edit made during install was rolled back"}
  }

  Invoke-Scenario "generated override with user addition" {
    param($tmp)
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.md"),"BASE RULE`r`n",(New-Object Text.UTF8Encoding($false)))
  } {
    param($tmp)
    $over=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.override.md")
    if($over -notmatch 'BASE RULE'){throw "generated override: base rule was not preserved"}
    if($over -notmatch 'USER ADDED TO GENERATED OVERRIDE'){throw "generated override: user addition was lost"}
    if($over -match 'CSF_CORE_ID='){throw "generated override: Smart Factory Core remained after uninstall"}
  }

  Invoke-Scenario "pre-existing override" {
    param($tmp)
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.md"),"BASE SHOULD REMAIN`r`n",(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.override.md"),"ORIGINAL OVERRIDE`r`n",(New-Object Text.UTF8Encoding($false)))
  } {
    param($tmp)
    $over=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.override.md")
    if($over -notmatch 'ORIGINAL OVERRIDE'){throw "pre-existing override not restored"}
    if($over -notmatch 'USER ADDED DURING INSTALL'){throw "user override edit made during install was lost"}
  }

  # Fresh-cycle regression: uninstall must delete its snapshot so a later install
  # captures the new state rather than restoring an ancient override.
  $tmp=Join-Path ([IO.Path]::GetTempPath()) ("csf-cycle-"+[guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  $env:CODEX_HOME=$tmp
  try{
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.override.md"),"FIRST OVERRIDE`r`n",(New-Object Text.UTF8Encoding($false)))
    & (Join-Path $RepoRoot "INSTALL.ps1") install -NoAutostart|Out-Null
    & (Join-Path $RepoRoot "INSTALL.ps1") uninstall|Out-Null
    [IO.File]::WriteAllText((Join-Path $tmp "AGENTS.override.md"),"SECOND OVERRIDE`r`n",(New-Object Text.UTF8Encoding($false)))
    & (Join-Path $RepoRoot "INSTALL.ps1") install -NoAutostart|Out-Null
    & (Join-Path $RepoRoot "INSTALL.ps1") uninstall|Out-Null
    $final=Get-Content -Raw -LiteralPath (Join-Path $tmp "AGENTS.override.md")
    if($final -notmatch 'SECOND OVERRIDE' -or $final -match 'FIRST OVERRIDE'){throw "fresh-cycle snapshot was stale"}
    Write-Host "PASS install/uninstall: fresh-cycle snapshot"
  }finally{Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue}

  Write-Host "PASS install/uninstall isolation (all scenarios)"
}finally{
  if($null -eq $old){Remove-Item Env:\CODEX_HOME -ErrorAction SilentlyContinue}else{$env:CODEX_HOME=$old}
}
