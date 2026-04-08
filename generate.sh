#!/bin/bash

set -euo pipefail

# Array to track failed commands (stores "dir: command" format)
declare -a FAILED_COMMANDS=()

# Function to run a command and track failures
run_command() {
    local cmd_string="$*"
    echo "  Running: $cmd_string"
    if ! "$@"; then
        FAILED_COMMANDS+=("$PWD: $cmd_string")
        echo "    FAILED: $cmd_string"
        return 1
    fi
    return 0
}

echo "Generating basic blog HTML..."
pushd basic-blog || { FAILED_COMMANDS+=("$PWD: pushd basic-blog"); exit 1; }
set +e
run_command lake update
run_command lake exe generate-blog
set -e
popd || exit 1

echo "Generating basic book HTML..."
pushd basic-book || { FAILED_COMMANDS+=("$PWD: pushd basic-book"); exit 1; }
set +e
run_command lake update
run_command lake exe generate-book
set -e
popd || exit 1

echo "Generating example blog HTML..."
pushd blog-features/blog || { FAILED_COMMANDS+=("$PWD: pushd blog-features/blog"); exit 1; }
set +e
run_command lake update
run_command lake exe generate-blog
set -e
popd || exit 1

echo "Generating example package documentation HTML..."
pushd package-docs/zippers || { FAILED_COMMANDS+=("$PWD: pushd package-docs/zippers"); exit 1; }
set +e
run_command lake update
set -e
popd || exit 1

pushd package-docs/manual || { FAILED_COMMANDS+=("$PWD: pushd package-docs/manual"); exit 1; }
set +e
run_command lake update
run_command lake exe docs
set -e
popd || exit 1

echo "Generating textbook HTML and code..."
pushd textbook || { FAILED_COMMANDS+=("$PWD: pushd textbook"); exit 1; }
set +e
run_command lake update
run_command lake exe textbook
set -e
cd _out || { FAILED_COMMANDS+=("$PWD: cd _out"); popd; exit 1; }
set +e
run_command zip -r code.zip example-code
set -e
popd || exit 1

echo "Generating slides HTML..."
pushd slides || { FAILED_COMMANDS+=("$PWD: pushd slides"); exit 1; }
set +e
run_command lake update
run_command lake exe generate-slides
set -e
popd || exit 1

echo "Collecting generated HTML..."
rm -rf out
mkdir -p out || { FAILED_COMMANDS+=("$PWD: mkdir -p out"); }
set +e
run_command cp -r basic-blog/_site out/basic-blog
run_command cp -r basic-book/_out/html-multi out/basic-book
run_command cp -r blog-features/blog/_site out/blog-features
run_command cp -r package-docs/manual/_out/html-multi out/package-docs
run_command cp -r textbook/_out/html-multi out/textbook
run_command cp textbook/_out/code.zip out/textbook/
run_command cp -r slides/_slides out/slides
set -e

# Report results
echo ""
if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
    echo "All commands completed successfully!"
    echo ""
    echo "The sites can be viewed by running a server. If in doubt, try the following command:"
    echo "python3 ./serve.py 8000"
    exit 0
else
    echo "==============================================="
    echo "FAILED COMMANDS (${#FAILED_COMMANDS[@]}):"
    echo "==============================================="
    for cmd in "${FAILED_COMMANDS[@]}"; do
        echo "  - $cmd"
    done
    echo ""
    echo "Generation completed with errors. Some outputs may be incomplete."
    exit 1
fi
