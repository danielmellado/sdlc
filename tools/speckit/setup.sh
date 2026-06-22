#!/usr/bin/env bash
# Initialize speckit in a project directory.
# Usage: ./setup.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"

if ! command -v specify &>/dev/null; then
    echo "Error: speckit (specify) not installed."
    echo "Run: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git"
    exit 1
fi

cd "$PROJECT_DIR"
echo "Initializing speckit in $(pwd)..."
specify init . --ai claude

echo
echo "Speckit initialized. Available commands in Claude Code:"
echo "  /speckit.specify    - Define requirements"
echo "  /speckit.plan       - Create implementation plan"
echo "  /speckit.tasks      - Generate task breakdown"
echo "  /speckit.implement  - Execute tasks"
echo "  /speckit.converge   - Assess progress and add remaining work"
