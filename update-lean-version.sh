#!/usr/bin/env bash

set -euo pipefail

# Script to update Lean version across the repository
# Updates lean-toolchain files and version-tagged rev entries in lakefile.toml files

if [ $# -ne 1 ]; then
    echo "Usage: $0 <new-lean-version>"
    echo "Example: $0 4.25.0"
    exit 1
fi

NEW_VERSION="$1"

# Validate version format: 4.X.Y or 4.X.Y-rcN
if ! [[ "$NEW_VERSION" =~ ^4\.[0-9]+\.[0-9]+(-rc[0-9]+)?$ ]]; then
    echo "Error: Invalid Lean version format: $NEW_VERSION"
    echo "Expected format: 4.X.Y or 4.X.Y-rcN (e.g., 4.25.0 or 4.30.0-rc1)"
    exit 1
fi

# Ensure we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "Updating Lean version to $NEW_VERSION..."
echo

# Track if any files were updated
FILES_UPDATED=0

# Track directories that need lake update
declare -a LAKE_DIRS=()

# Function to check if a file is under version control
is_tracked() {
    git ls-files --error-unmatch "$1" > /dev/null 2>&1
}

# Update lean-toolchain files
echo "Updating lean-toolchain files..."
while IFS= read -r file; do
    if is_tracked "$file"; then
        echo "  Updating $file"
        # Update the version, handling both with and without 'v' prefix
        sed -i.bak -E "s|leanprover/lean4:v?[0-9][^[:space:]]*|leanprover/lean4:$NEW_VERSION|" "$file"
        rm -f "$file.bak"
        FILES_UPDATED=$((FILES_UPDATED + 1))
    fi
done < <(git ls-files | grep -E 'lean-toolchain$' | grep -v '^blog-examples/')

echo

# Update lakefile.toml files and collect directories for lake update
echo "Updating version-tagged rev entries in lakefile.toml files..."
while IFS= read -r file; do
    if is_tracked "$file"; then
        # Add directory to lake update list
        dir=$(dirname "$file")
        LAKE_DIRS+=("$dir")

        # Check if file has version-tagged rev entries (rev = "v<number>...")
        if grep -q 'rev[[:space:]]*=[[:space:]]*"v[0-9]' "$file"; then
            echo "  Updating $file"
            # Ensure NEW_VERSION has 'v' prefix for lakefile.toml
            VERSION_WITH_V="$NEW_VERSION"
            if [[ ! "$VERSION_WITH_V" =~ ^v ]]; then
                VERSION_WITH_V="v$NEW_VERSION"
            fi
            # Update rev = "v..." entries (preserving any existing v prefix)
            sed -i.bak "s|rev[[:space:]]*=[[:space:]]*\"v[0-9][^\"]*\"|rev = \"$VERSION_WITH_V\"|" "$file"
            rm -f "$file.bak"
            FILES_UPDATED=$((FILES_UPDATED + 1))
        fi
    fi
done < <(git ls-files | grep -E 'lakefile\.toml$' | grep -v '^blog-examples/')

echo

if [ $FILES_UPDATED -gt 0 ]; then
    echo "Successfully updated $FILES_UPDATED file(s) to version $NEW_VERSION"
    echo
    echo "Review the changes with: git diff"
else
    echo "No files were updated"
fi

# Run lake update in directories with lakefile.toml
if [ ${#LAKE_DIRS[@]} -gt 0 ]; then
    echo
    echo "Running lake update in directories with lakefile.toml..."
    echo

    for dir in "${LAKE_DIRS[@]}"; do
        echo "  Running lake update in $dir..."
        # Temporarily disable exit on error for lake update
        set +e
        (cd "$dir" && lake update)
        exit_code=$?
        set -e

        if [ $exit_code -ne 0 ]; then
            echo "    Warning: lake update failed in $dir (exit code: $exit_code)"
        fi
    done

    echo
    echo "Lake updates complete"
fi

# Update subverso rev in package-docs/zippers/lakefile.toml based on package-docs/manual manifest
ZIPPERS_LAKEFILE="package-docs/zippers/lakefile.toml"
MANUAL_MANIFEST="package-docs/manual/lake-manifest.json"

if [ -f "$MANUAL_MANIFEST" ] && [ -f "$ZIPPERS_LAKEFILE" ]; then
    echo
    echo "Updating subverso rev in $ZIPPERS_LAKEFILE..."

    # Extract subverso rev from manual's lake-manifest.json
    SUBVERSO_REV=$(jq -r '.packages[] | select(.name == "subverso") | .rev' "$MANUAL_MANIFEST")

    if [ -n "$SUBVERSO_REV" ]; then
        echo "  Found subverso rev in manual manifest: $SUBVERSO_REV"
        echo "  Setting subverso rev to: no-modules/$SUBVERSO_REV"

        # Update the subverso rev in zippers lakefile.toml
        sed -i.bak "/name = \"subverso\"/,/^$/s|rev = \"[^\"]*\"|rev = \"no-modules/${SUBVERSO_REV}\"|" "$ZIPPERS_LAKEFILE"
        rm -f "$ZIPPERS_LAKEFILE.bak"
        echo "  Updated $ZIPPERS_LAKEFILE"

        # Run lake update in zippers directory
        ZIPPERS_DIR=$(dirname "$ZIPPERS_LAKEFILE")
        echo "  Running lake update in $ZIPPERS_DIR..."
        set +e
        (cd "$ZIPPERS_DIR" && lake update)
        exit_code=$?
        set -e
        if [ $exit_code -ne 0 ]; then
            echo "    Warning: lake update failed in $ZIPPERS_DIR (exit code: $exit_code)"
        fi
    else
        echo "  Warning: Could not extract subverso rev from $MANUAL_MANIFEST"
    fi
fi

# Update subverso ref/rev in blog-examples directories
if [ -f "$MANUAL_MANIFEST" ]; then
    # Extract subverso rev from manual's lake-manifest.json
    SUBVERSO_REV=$(jq -r '.packages[] | select(.name == "subverso") | .rev' "$MANUAL_MANIFEST")

    if [ -n "$SUBVERSO_REV" ]; then
        echo
        echo "Updating subverso references in blog-examples to: no-modules/$SUBVERSO_REV"

        # Update lakefile.lean files in blog-examples
        while IFS= read -r file; do
            if is_tracked "$file"; then
                echo "  Updating $file"
                # Update @"main" or @"anything" to @"no-modules/$SUBVERSO_REV" in lakefile.lean
                sed -i.bak "s|@\"[^\"]*\"|@\"no-modules/$SUBVERSO_REV\"|" "$file"
                rm -f "$file.bak"
            fi
        done < <(git ls-files | grep -E '^blog-examples/.*/lakefile\.lean$')

        # Update lakefile.toml files in blog-examples
        while IFS= read -r file; do
            if is_tracked "$file"; then
                echo "  Updating $file"
                # Update ref or rev in lakefile.toml (handles both ref = "..." and rev = "...")
                # Update both ref and rev to handle both field names
                sed -i.bak "/name = \"subverso\"/,/^$/{
                    s|ref = \"[^\"]*\"|ref = \"no-modules/$SUBVERSO_REV\"|
                    s|rev = \"[^\"]*\"|rev = \"no-modules/$SUBVERSO_REV\"|
                }" "$file"
                rm -f "$file.bak"
            fi
        done < <(git ls-files | grep -E '^blog-examples/.*/lakefile\.toml$')

        # Run lake update in blog-examples directories
        echo
        echo "Running lake update in blog-examples directories..."
        for dir in blog-examples/*/; do
            if [ -d "$dir" ] && { [ -f "$dir/lakefile.lean" ] || [ -f "$dir/lakefile.toml" ]; }; then
                echo "  Running lake update in $dir..."
                set +e
                (cd "$dir" && lake update)
                exit_code=$?
                set -e
                if [ $exit_code -ne 0 ]; then
                    echo "    Warning: lake update failed in $dir (exit code: $exit_code)"
                fi
            fi
        done
    fi
fi
