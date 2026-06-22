#!/usr/bin/env bash
# Wrapper to launch Claude Code inside a nono sandbox.
# Uses the claude-code profile from this repo.
#
# Usage:
#   nono-claude                         # sandbox in current directory
#   nono-claude --model opus            # use a specific model
#   nono-claude --rc                    # enable Remote Control (browser access)
#   nono-claude --model sonnet --rc     # both
#   nono-claude --allow ~/other/repo    # allow extra paths
#   nono-claude -- --resume             # pass arbitrary args to claude

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${SCRIPT_DIR}/../claude-code.json"

NONO_ARGS=()
CLAUDE_ARGS=()
PARSING_CLAUDE=false
SKIP_NEXT=false

for i in $(seq 1 $#); do
    arg="${!i}"
    if [[ "$SKIP_NEXT" == true ]]; then
        SKIP_NEXT=false
        continue
    fi
    if [[ "$PARSING_CLAUDE" == true ]]; then
        CLAUDE_ARGS+=("$arg")
    elif [[ "$arg" == "--" ]]; then
        PARSING_CLAUDE=true
    elif [[ "$arg" == "--model" ]]; then
        next=$((i + 1))
        CLAUDE_ARGS+=("--model" "${!next}")
        SKIP_NEXT=true
    elif [[ "$arg" == "--rc" || "$arg" == "--remote-control" ]]; then
        CLAUDE_ARGS+=("--remote-control")
    else
        NONO_ARGS+=("$arg")
    fi
done

if ! command -v nono &>/dev/null; then
    echo "Error: nono is not installed. Run: cargo install nono-cli"
    echo "  or:  brew install nono"
    exit 1
fi

exec nono run \
    --profile "$PROFILE" \
    --allow . \
    "${NONO_ARGS[@]}" \
    -- claude "${CLAUDE_ARGS[@]}"
