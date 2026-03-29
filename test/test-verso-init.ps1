# Test suite for verso-init.ps1
# Usage: pwsh test/test-verso-init.ps1 [-Branch BRANCH]

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param(
    [string]$Branch = "main"
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SetupPs1 = Join-Path $RepoRoot "verso-init.ps1"

$Passed = 0
$Failed = 0
$Errors = @()

function Pass($msg) {
    $script:Passed++
    Write-Host "  PASS: $msg"
}

function Fail($msg) {
    $script:Failed++
    $script:Errors += "  FAIL: $msg"
    Write-Host "  FAIL: $msg"
}

# Create a fake elan so prerequisite checks pass
$FakeBin = Join-Path ([System.IO.Path]::GetTempPath()) "verso-test-bin-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $FakeBin | Out-Null

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) "verso-test-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $WorkDir | Out-Null

try {
    # Create fake elan executable
    if ($IsWindows -or (-not $IsLinux -and -not $IsMacOS)) {
        # Windows: create a .bat file
        Set-Content -Path "$FakeBin/elan.bat" -Value '@echo elan mock'
        # Also create a .cmd for PowerShell's Get-Command
        Set-Content -Path "$FakeBin/elan.cmd" -Value '@echo elan mock'
    } else {
        # Unix: create a shell script
        Set-Content -Path "$FakeBin/elan" -Value "#!/bin/sh`necho 'elan mock'"
        chmod +x "$FakeBin/elan"
    }
    $env:PATH = "$FakeBin$([System.IO.Path]::PathSeparator)$env:PATH"

    # --- Tests ---

    Write-Host "Test: -Help flag"
    $output = pwsh $SetupPs1 -Help 2>&1 | Out-String
    if ($output -match "Usage:") { Pass "-Help prints usage" } else { Fail "-Help prints usage" }

    Write-Host "Test: -List flag"
    $output = pwsh $SetupPs1 -List -Branch $Branch 2>&1 | Out-String
    if ($output -match "basic-blog") { Pass "-List shows basic-blog template" } else { Fail "-List shows basic-blog template" }
    if ($output -match "textbook") { Pass "-List shows textbook template" } else { Fail "-List shows textbook template" }
    if ($output -match "package-docs") { Pass "-List shows package-docs template" } else { Fail "-List shows package-docs template" }

    Write-Host "Test: batch mode with basic-blog template"
    $target = Join-Path $WorkDir "test-blog"
    $output = pwsh -File $SetupPs1 -Branch $Branch basic-blog $target 2>&1 | Out-String
    if (-not (Test-Path "$target/lakefile.toml")) { Write-Host "DEBUG batch output: $output" }
    if (Test-Path "$target/lakefile.toml") { Pass "basic-blog: lakefile.toml exists" } else { Fail "basic-blog: lakefile.toml exists" }
    if (Test-Path "$target/lean-toolchain") { Pass "basic-blog: lean-toolchain exists" } else { Fail "basic-blog: lean-toolchain exists" }
    if (Test-Path "$target/README.md") { Pass "basic-blog: README.md exists" } else { Fail "basic-blog: README.md exists" }
    if (-not (Test-Path "$target/.lake")) { Pass "basic-blog: no .lake directory" } else { Fail "basic-blog: no .lake directory" }
    $commitCount = git -C $target rev-list --count HEAD
    if ($commitCount -eq "1") { Pass "basic-blog: exactly one commit" } else { Fail "basic-blog: exactly one commit (got $commitCount)" }
    $commitMsg = git -C $target log --oneline -1
    if ($commitMsg -match "verso-templates/basic-blog") { Pass "basic-blog: commit message mentions template" } else { Fail "basic-blog: commit message mentions template (got: $commitMsg)" }

    Write-Host "Test: batch mode with textbook template"
    $target = Join-Path $WorkDir "test-textbook"
    pwsh -File $SetupPs1 -Branch $Branch textbook $target 2>&1 | Out-Null
    if (Test-Path "$target/lakefile.toml") { Pass "textbook: lakefile.toml exists" } else { Fail "textbook: lakefile.toml exists" }
    $commitCount = git -C $target rev-list --count HEAD
    if ($commitCount -eq "1") { Pass "textbook: exactly one commit" } else { Fail "textbook: exactly one commit (got $commitCount)" }

    Write-Host "Test: batch mode with package-docs template"
    $target = Join-Path $WorkDir "test-docs"
    pwsh -File $SetupPs1 -Branch $Branch package-docs $target 2>&1 | Out-Null
    if (Test-Path "$target/manual/lakefile.toml") { Pass "package-docs: manual/lakefile.toml exists" } else { Fail "package-docs: manual/lakefile.toml exists" }
    if (Test-Path "$target/manual/Main.lean") { Pass "package-docs: manual/Main.lean exists" } else { Fail "package-docs: manual/Main.lean exists" }
    $commitCount = git -C $target rev-list --count HEAD
    if ($commitCount -eq "1") { Pass "package-docs: exactly one commit" } else { Fail "package-docs: exactly one commit (got $commitCount)" }

    Write-Host "Test: error when directory exists"
    $target = Join-Path $WorkDir "test-exists"
    New-Item -ItemType Directory -Path $target | Out-Null
    pwsh $SetupPs1 -Branch $Branch basic-blog $target 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Pass "fails when directory exists" } else { Fail "should fail when directory exists" }

    Write-Host "Test: error with nonexistent template"
    $target = Join-Path $WorkDir "test-bad"
    pwsh $SetupPs1 -Branch $Branch nonexistent $target 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Pass "fails with bad template name" } else { Fail "should fail with bad template name" }

    Write-Host "Test: error when elan is not installed"
    # Remove all paths containing 'elan' and the fake bin from PATH
    $savedPath = $env:PATH
    $env:PATH = ($env:PATH -split [System.IO.Path]::PathSeparator | Where-Object { $_ -ne $FakeBin -and $_ -notmatch 'elan' }) -join [System.IO.Path]::PathSeparator
    $noElanOutput = pwsh $SetupPs1 -Branch $Branch basic-blog (Join-Path $WorkDir "no-elan") 2>&1 | Out-String
    $env:PATH = $savedPath
    if ($noElanOutput -match "elan.*not installed") { Pass "fails with helpful message when elan missing" } else { Fail "fails with helpful message when elan missing (got: $noElanOutput)" }

    Write-Host "Test: interactive mode via stdin piping"
    $target = Join-Path $WorkDir "test-interactive"
    "1", $target | pwsh $SetupPs1 -Branch $Branch 2>&1 | Out-Null
    if ((Test-Path "$target/lakefile.toml") -and $LASTEXITCODE -eq 0) {
        Pass "interactive: project created successfully"
    } else {
        Fail "interactive: project created successfully"
    }
    if (Test-Path $target) {
        $commitCount = git -C $target rev-list --count HEAD
        if ($commitCount -eq "1") { Pass "interactive: exactly one commit" } else { Fail "interactive: exactly one commit (got $commitCount)" }
    }

} finally {
    if (Test-Path $WorkDir) { Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $FakeBin) { Remove-Item -Path $FakeBin -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "=== Results: $Passed passed, $Failed failed ==="
if ($Failed -gt 0) {
    $Errors | ForEach-Object { Write-Host $_ }
    exit 1
}
