#!/usr/bin/env bash
# Install the caveman plugin for Claude Code.
# Reduces output tokens by ~75%.
set -euo pipefail

if ! command -v claude &>/dev/null; then
    echo "Error: Claude Code CLI not installed."
    echo "Run: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

echo "Installing caveman plugin..."
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman

echo
echo "Caveman installed. Usage in Claude Code:"
echo "  /caveman            - Enable caveman mode (default: full)"
echo "  /caveman lite       - Light compression, keeps grammar"
echo "  /caveman full       - Default, drops articles, uses fragments"
echo "  /caveman ultra      - Maximum compression"
echo "  /caveman-compress   - Compress CLAUDE.md to save input tokens (~46%)"
echo "  /caveman-stats      - Show token savings"
