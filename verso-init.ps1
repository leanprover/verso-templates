# Setup script for creating new Verso projects from templates.
# Usage:
#   Interactive:  powershell -c "irm https://raw.githubusercontent.com/leanprover/verso-templates/main/verso-init.ps1 | iex"
#   Batch:        pwsh verso-init.ps1 [-Version VERSION] <template> <directory>
#   List:         pwsh verso-init.ps1 -List

# Write-Host is intentional: this is an interactive setup script, not a pipeline cmdlet.
# Output must go to the console, not the pipeline (especially for irm | iex).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
[CmdletBinding()]
param(
    [switch]$List,
    [string]$Version = "",
    [string]$Branch = "",
    [switch]$Help,
    [Parameter(Position = 0)]
    [string]$Template = "",
    [Parameter(Position = 1)]
    [string]$Directory = ""
)

$ErrorActionPreference = 'Stop'

$RepoUrl = "https://github.com/leanprover/verso-templates.git"
$TempDir = $null

function Show-Usage {
    Write-Host @"
Usage: verso-init.ps1 [OPTIONS] [<template> <directory>]

Create a new Verso project from a template.

When run without arguments, enters interactive mode.

Options:
  -List             List available templates
  -Version VER      Use a specific version tag (e.g. v4.28.0). Default: latest stable
  -Branch BRANCH    Use a specific branch (overrides -Version)
  -Help             Show this help message

Examples:
  pwsh verso-init.ps1 blog my-blog
  pwsh verso-init.ps1 -Version v4.28.0 textbook my-textbook
  pwsh verso-init.ps1 package-docs my-docs
  powershell -c "irm https://raw.githubusercontent.com/leanprover/verso-templates/main/verso-init.ps1 | iex"
"@
}

function Read-UserInput {
    param([string]$Prompt)
    if ([Console]::IsInputRedirected) {
        Write-Host $Prompt -NoNewline
        return [Console]::ReadLine()
    } else {
        return Read-Host $Prompt
    }
}

function Test-Prerequisite {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "Error: 'git' is not installed. Please install git: https://git-scm.com/downloads"
        exit 1
    }
    if (-not (Get-Command elan -ErrorAction SilentlyContinue)) {
        Write-Error "Error: 'elan' is not installed. elan is the Lean version manager, required to build Lean projects. Install it from: https://github.com/leanprover/elan#installation"
        exit 1
    }
}

function Resolve-TemplateVersion {
    param([string]$RequestedVersion, [string]$RequestedBranch)

    # Explicit branch overrides everything
    if ($RequestedBranch) {
        return $RequestedBranch
    }

    # Fetch available tags
    $rawTags = git ls-remote --tags $RepoUrl 2>$null
    $tags = @()
    if ($rawTags) {
        $tags = $rawTags | ForEach-Object {
            if ($_ -match 'refs/tags/(v[0-9][^\^]*)$') { $Matches[1] }
        } | Where-Object { $_ } | Sort-Object
    }

    if ($RequestedVersion -and $RequestedVersion -ne "latest") {
        if ($tags -contains $RequestedVersion) {
            return $RequestedVersion
        }
        Write-Host "Error: version '$RequestedVersion' not found." -ForegroundColor Red
        if ($tags.Count -gt 0) {
            Write-Host "Available versions:"
            $tags | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "No version tags found in the repository."
        }
        exit 1
    }

    # Find latest stable (no -rc suffix)
    $stable = $tags | Where-Object { $_ -notmatch '-rc' }
    if ($stable) {
        if ($stable -is [array]) { return $stable[-1] } else { return $stable }
    }

    # No stable tags, fall back to main
    return "main"
}

function Initialize-TempClone {
    param([string]$Ref)
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "verso-setup-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TempDir | Out-Null

    Write-Host "Fetching templates ($Ref)..."
    $ErrorActionPreference = 'Continue'
    git clone --depth 1 --single-branch --branch $Ref $RepoUrl "$($script:TempDir)/repo" 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to fetch templates. Check your network connection and try again."
        exit 1
    }
}

function Find-Template {
    param([string]$RepoRoot)
    $templates = @()
    # Templates are top-level directories that recursively contain at least one lakefile
    Get-ChildItem -Path $RepoRoot -Directory | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'out' } | ForEach-Object {
        $dir = $_.FullName
        $lakefiles = Get-ChildItem -Path $dir -Filter "lakefile.*" -Recurse -File | Where-Object { $_.Name -match '^lakefile\.(toml|lean)$' }
        if ($lakefiles) {
            $templates += $_.Name
        }
    }
    return $templates | Sort-Object
}

function Get-TemplateDescription {
    param([string]$TemplatePath)
    $readme = Join-Path $TemplatePath "README.md"
    if (Test-Path $readme) {
        $firstLine = Get-Content $readme -TotalCount 1
        return $firstLine -replace '^#*\s*', ''
    }
    return ""
}

function Show-TemplateList {
    param([string]$RepoRoot, [string[]]$Templates)
    Write-Host "Available templates:"
    $i = 1
    foreach ($tmpl in $Templates) {
        $desc = Get-TemplateDescription (Join-Path $RepoRoot $tmpl)
        $padded = $tmpl.PadRight(25)
        Write-Host "  $i) $padded $desc"
        $i++
    }
}

function New-VersoProject {
    param([string]$Template, [string]$Directory, [string]$RepoRoot)

    $templateDir = Join-Path $RepoRoot $Template

    # Validate template: must be a directory that recursively contains a lakefile
    $lakefiles = if (Test-Path $templateDir) {
        Get-ChildItem -Path $templateDir -Filter "lakefile.*" -Recurse -File | Where-Object { $_.Name -match '^lakefile\.(toml|lean)$' }
    } else { $null }
    if (-not $lakefiles) {
        Write-Host "Error: '$Template' is not a valid template." -ForegroundColor Red
        $templates = Find-Template $RepoRoot
        Write-Host "Available templates:"
        $templates | ForEach-Object { Write-Host "  $_" }
        exit 1
    }

    # Validate target directory does not exist
    if (Test-Path $Directory) {
        Write-Error "Error: '$Directory' already exists. Please choose a different directory name or remove the existing one."
        exit 1
    }

    Write-Host ""
    Write-Host "Creating project from '$Template' in '$Directory'..."

    # Copy template files (target dir must not exist yet, which we validated above)
    Copy-Item -Path $templateDir -Destination $Directory -Recurse

    # Remove build artifacts recursively (shouldn't be in a clone, but be defensive)
    Get-ChildItem -Path $Directory -Directory -Recurse | Where-Object { $_.Name -in @(".lake", "_site", "_out") } | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Initialize new git repo
    $ErrorActionPreference = 'Continue'
    git -C $Directory init -q 2>&1 | Out-Null
    git -C $Directory add . 2>&1 | Out-Null
    git -C $Directory commit -q -m "Initial commit from verso-templates/$Template" 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'

    Write-Host ""
    Write-Host "Created new Verso project in '$Directory' from template '$Template'."
    Write-Host ""
    Write-Host "To get started:"
    Write-Host "  cd $Directory"
    if ((Test-Path "$Directory/lakefile.toml") -or (Test-Path "$Directory/lakefile.lean")) {
        Write-Host "  lake build"
    } else {
        Write-Host "  See README.md for build instructions."
    }
    Write-Host ""
}

# --- Main ---

try {
    if ($Help) {
        Show-Usage
        exit 0
    }

    Test-Prerequisite

    $resolvedRef = Resolve-TemplateVersion -RequestedVersion $Version -RequestedBranch $Branch

    if ($List) {
        Initialize-TempClone $resolvedRef
        $templates = Find-Template "$TempDir/repo"
        if ($templates.Count -eq 0) {
            Write-Error "No templates found in the repository."
            exit 1
        }
        Show-TemplateList "$TempDir/repo" $templates
        exit 0
    }

    if (-not $Template -and -not $Directory) {
        # Interactive mode
        Write-Host ""
        Write-Host "Verso Project Setup"
        Write-Host "==================="
        Write-Host ""

        Initialize-TempClone $resolvedRef

        $templates = Find-Template "$TempDir/repo"
        if ($templates.Count -eq 0) {
            Write-Error "No templates found in the repository."
            exit 1
        }

        Write-Host ""
        Show-TemplateList "$TempDir/repo" $templates

        Write-Host ""
        $selection = Read-UserInput "Select a template [1-$($templates.Count)]"

        $selNum = 0
        if (-not [int]::TryParse($selection, [ref]$selNum) -or $selNum -lt 1 -or $selNum -gt $templates.Count) {
            Write-Error "Invalid selection: '$selection'"
            exit 1
        }

        $Template = $templates[$selNum - 1]

        Write-Host ""
        $Directory = Read-UserInput "Directory name"

        if (-not $Directory) {
            Write-Error "Directory name cannot be empty."
            exit 1
        }

        New-VersoProject -Template $Template -Directory $Directory -RepoRoot "$TempDir/repo"
    } elseif ($Template -and $Directory) {
        # Batch mode
        Initialize-TempClone $resolvedRef
        New-VersoProject -Template $Template -Directory $Directory -RepoRoot "$TempDir/repo"
    } else {
        Write-Error "Both <template> and <directory> are required. Run with -Help for usage."
        exit 1
    }
} finally {
    if ($TempDir -and (Test-Path $TempDir)) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
