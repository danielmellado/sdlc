#!/usr/bin/env bash
# Install diffity and its Claude Code skills in a project.
# Usage: ./setup.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"

if ! command -v diffity &>/dev/null; then
    echo "Installing diffity globally..."
    npm install -g diffity
fi

cd "$PROJECT_DIR"
echo "Installing diffity skills in $(pwd)..."
npx skills add kamranahmedse/diffity

echo
echo "Diffity ready. Available commands in Claude Code:"
echo "  /diffity-diff       - Open diff viewer in browser"
echo "  /diffity-review     - AI reviews your diff with inline comments"
echo "  /diffity-resolve    - Apply fixes from review comments"
echo
echo "Workflow: make changes -> /diffity-review -> check browser -> /diffity-resolve"
