#!/bin/sh
# Setup script for creating new Verso projects from templates.
# Usage:
#   Interactive:  curl -sSfL https://raw.githubusercontent.com/leanprover/verso-templates/main/verso-init.sh | sh
#   Batch:        verso-init.sh [--version VERSION] <template> <directory>
#   List:         verso-init.sh --list
set -eu

REPO_URL="https://github.com/leanprover/verso-templates.git"
RESOLVED_REF=""
TMPDIR_SETUP=""

usage() {
    cat <<'EOF'
Usage: verso-init.sh [OPTIONS] [<template> <directory>]

Create a new Verso project from a template.

When run without arguments, enters interactive mode.

Options:
  --list, -l        List available templates
  --version VER     Use a specific version tag (e.g. v4.28.0). Default: latest stable
  --branch BRANCH   Use a specific branch (overrides --version)
  --help, -h        Show this help message

Examples:
  verso-init.sh blog my-blog
  verso-init.sh --version v4.28.0 textbook my-textbook
  verso-init.sh package-docs my-docs
  curl -sSfL https://raw.githubusercontent.com/leanprover/verso-templates/main/verso-init.sh | sh
  curl -sSfL https://raw.githubusercontent.com/leanprover/verso-templates/main/verso-init.sh | sh -s -- blog my-blog
EOF
}

cleanup() {
    if [ -n "$TMPDIR_SETUP" ] && [ -d "$TMPDIR_SETUP" ]; then
        rm -rf "$TMPDIR_SETUP"
    fi
}
trap cleanup EXIT INT TERM

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

# Read a line from the user, even when stdin is a pipe (curl | sh)
prompt_read() {
    printf '%s' "$1" > /dev/tty
    read -r REPLY < /dev/tty
}

check_prerequisites() {
    if ! command -v git >/dev/null 2>&1; then
        die "'git' is not installed. Please install git: https://git-scm.com/downloads"
    fi
    if ! command -v elan >/dev/null 2>&1; then
        die "'elan' is not installed. elan is the Lean version manager, required to build Lean projects. Install it from: https://github.com/leanprover/elan#installation"
    fi
}

# Resolve which git ref to clone. Sets RESOLVED_REF.
# Arguments: $1 = explicit version (may be empty), $2 = explicit branch (may be empty)
resolve_version() {
    version="$1"
    branch="$2"

    # Explicit branch overrides everything
    if [ -n "$branch" ]; then
        RESOLVED_REF="$branch"
        return
    fi

    # Fetch available tags
    tags=$(git ls-remote --tags "$REPO_URL" 2>/dev/null | sed -n 's|.*refs/tags/\(v[0-9].*\)$|\1|p' | grep -v '\^{}' | sort -t. -k1,1n -k2,2n -k3,3n || true)

    if [ -n "$version" ] && [ "$version" != "latest" ]; then
        # Validate the requested version exists
        if echo "$tags" | grep -qx "$version"; then
            RESOLVED_REF="$version"
        else
            echo "Error: version '$version' not found." >&2
            if [ -n "$tags" ]; then
                echo "Available versions:" >&2
                echo "$tags" | sed 's/^/  /' >&2
            else
                echo "No version tags found in the repository." >&2
            fi
            exit 1
        fi
        return
    fi

    # Find latest stable (no -rc suffix)
    stable=$(echo "$tags" | grep -v -- '-rc' || true)
    if [ -n "$stable" ]; then
        RESOLVED_REF=$(echo "$stable" | tail -1)
    else
        # No stable tags, fall back to main
        RESOLVED_REF="main"
    fi
}

clone_repo() {
    TMPDIR_SETUP=$(mktemp -d)
    echo "Fetching templates ($RESOLVED_REF)..."
    if ! git clone --depth 1 --single-branch --branch "$RESOLVED_REF" "$REPO_URL" "$TMPDIR_SETUP/repo" >/dev/null 2>&1; then
        die "Failed to fetch templates. Check your network connection and try again."
    fi
}

# Find template directories: top-level directories that recursively contain
# at least one lakefile.toml or lakefile.lean.
# Prints directory names, one per line.
find_templates() {
    repo_root="$1"
    for dir in "$repo_root"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        # Skip hidden directories and common non-template dirs
        case "$name" in
            .*|out) continue ;;
        esac
        if find "$dir" \( -name "lakefile.toml" -o -name "lakefile.lean" \) -type f | grep -q .; then
            echo "$name"
        fi
    done | sort
}

# Get the description for a template (first line of README.md, stripping # prefix)
template_description() {
    readme="$1/README.md"
    if [ -f "$readme" ]; then
        head -1 "$readme" | sed 's/^#* *//'
    fi
}

list_templates() {
    clone_repo
    templates=$(find_templates "$TMPDIR_SETUP/repo")
    if [ -z "$templates" ]; then
        die "No templates found in the repository."
    fi
    echo "Available templates:"
    echo "$templates" | while IFS= read -r tmpl; do
        desc=$(template_description "$TMPDIR_SETUP/repo/$tmpl")
        printf "  %-25s %s\n" "$tmpl" "$desc"
    done
}

interactive_mode() {
    # Check that we have a terminal for interactive input
    if ! test -t 0 && ! test -e /dev/tty; then
        die "No terminal available for interactive mode. Please provide arguments: verso-init.sh <template> <directory>"
    fi

    echo ""
    echo "Verso Project Setup"
    echo "==================="
    echo ""

    clone_repo

    templates=$(find_templates "$TMPDIR_SETUP/repo")
    if [ -z "$templates" ]; then
        die "No templates found in the repository."
    fi

    echo ""
    echo "Available templates:"
    i=1
    echo "$templates" | while IFS= read -r tmpl; do
        desc=$(template_description "$TMPDIR_SETUP/repo/$tmpl")
        printf "  %d) %-25s %s\n" "$i" "$tmpl" "$desc"
        i=$((i + 1))
    done

    template_count=$(echo "$templates" | wc -l | tr -d ' ')
    echo ""
    prompt_read "Select a template [1-$template_count]: "
    selection="$REPLY"

    # Validate selection is a number in range
    case "$selection" in
        ''|*[!0-9]*) die "Invalid selection: '$selection'" ;;
    esac
    if [ "$selection" -lt 1 ] || [ "$selection" -gt "$template_count" ]; then
        die "Selection out of range: $selection (expected 1-$template_count)"
    fi

    TEMPLATE=$(echo "$templates" | sed -n "${selection}p")

    echo ""
    prompt_read "Directory name: "
    DIRECTORY="$REPLY"

    if [ -z "$DIRECTORY" ]; then
        die "Directory name cannot be empty."
    fi

    create_project "$TEMPLATE" "$DIRECTORY"
}

create_project() {
    template="$1"
    directory="$2"
    template_dir="$TMPDIR_SETUP/repo/$template"

    # Validate template: must be a directory that recursively contains a lakefile
    if [ ! -d "$template_dir" ] || ! find "$template_dir" \( -name "lakefile.toml" -o -name "lakefile.lean" \) -type f | grep -q .; then
        echo "Error: '$template' is not a valid template." >&2
        echo "Available templates:" >&2
        find_templates "$TMPDIR_SETUP/repo" | sed 's/^/  /' >&2
        exit 1
    fi

    # Validate target directory does not exist
    if [ -e "$directory" ]; then
        die "'$directory' already exists. Please choose a different directory name or remove the existing one."
    fi

    echo ""
    echo "Creating project from '$template' in '$directory'..."

    # Copy template files
    mkdir -p "$directory"
    cp -a "$template_dir/." "$directory/"

    # Remove build artifacts (shouldn't be in a clone, but be defensive)
    find "$directory" -type d \( -name ".lake" -o -name "_site" -o -name "_out" \) -exec rm -rf {} + 2>/dev/null || true

    # Initialize new git repo
    git -C "$directory" init -q
    git -C "$directory" add .
    git -C "$directory" commit -q -m "Initial commit from verso-templates/$template"

    echo ""
    echo "Created new Verso project in '$directory' from template '$template'."
    echo ""
    echo "To get started:"
    echo "  cd $directory"
    echo "  lake build"
    echo ""
}

# --- Main ---

check_prerequisites

# Parse arguments
VERSION=""
BRANCH=""
MODE=""
TEMPLATE=""
DIRECTORY=""

while [ $# -gt 0 ]; do
    case "$1" in
        --list|-l)
            MODE="list"
            shift
            ;;
        --version)
            [ $# -ge 2 ] || die "--version requires an argument"
            VERSION="$2"
            shift 2
            ;;
        --branch)
            [ $# -ge 2 ] || die "--branch requires an argument"
            BRANCH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            if [ -z "$TEMPLATE" ]; then
                TEMPLATE="$1"
            elif [ -z "$DIRECTORY" ]; then
                DIRECTORY="$1"
            else
                die "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

resolve_version "$VERSION" "$BRANCH"

if [ "$MODE" = "list" ]; then
    list_templates
    exit 0
fi

if [ -z "$TEMPLATE" ] && [ -z "$DIRECTORY" ]; then
    interactive_mode
    exit 0
fi

if [ -z "$TEMPLATE" ] || [ -z "$DIRECTORY" ]; then
    die "Both <template> and <directory> are required. Run with --help for usage."
fi

# Batch mode
clone_repo
create_project "$TEMPLATE" "$DIRECTORY"
