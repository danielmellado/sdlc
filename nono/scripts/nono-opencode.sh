#!/usr/bin/env bash
# Wrapper to launch OpenCode inside a nono sandbox.
# Uses the opencode profile from this repo.
#
# Usage:
#   nono-opencode                       # sandbox in current directory
#   nono-opencode --local               # use Ollama (local LLM)
#   nono-opencode --allow ~/other/repo  # allow extra paths
#   nono-opencode -- --resume           # pass arbitrary args to opencode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PROFILE="${SCRIPT_DIR}/../opencode.json"

NONO_ARGS=()
OC_ARGS=()
PARSING_OC=false
SKIP_NEXT=false

for i in $(seq 1 $#); do
    arg="${!i}"
    if [[ "$SKIP_NEXT" == true ]]; then
        SKIP_NEXT=false
        continue
    fi
    if [[ "$PARSING_OC" == true ]]; then
        OC_ARGS+=("$arg")
    elif [[ "$arg" == "--" ]]; then
        PARSING_OC=true
    elif [[ "$arg" == "--local" ]]; then
        export OPENCODE_PROVIDER="${OPENCODE_PROVIDER:-ollama}"
        export OPENCODE_MODEL="${OPENCODE_MODEL:-devstral-small-2}"
    elif [[ "$arg" == "--provider" ]]; then
        next=$((i + 1))
        export OPENCODE_PROVIDER="${!next}"
        SKIP_NEXT=true
    else
        NONO_ARGS+=("$arg")
    fi
done

if ! command -v nono &>/dev/null; then
    echo "Error: nono is not installed. Run: cargo install nono-cli"
    echo "  or:  brew install nono"
    exit 1
fi

if ! command -v opencode &>/dev/null; then
    echo "Error: opencode is not installed. Run: npm install -g opencode-ai@latest"
    echo "  or:  brew install anomalyco/tap/opencode"
    exit 1
fi

# Use --allow-cwd for project dirs, but guard against running from $HOME
# (nono deny rules for sensitive dotfiles conflict with broad $HOME access)
if [[ "$(pwd)" == "$HOME" ]]; then
    echo "Warning: Running from \$HOME is not recommended (sandbox deny-rule conflicts)."
    echo "  cd into a project directory first, e.g.:  cd ~/myproject && nono-opencode"
    exit 1
fi

exec nono run \
    --profile "$PROFILE" \
    --allow-cwd \
    "${NONO_ARGS[@]}" \
    -- opencode "${OC_ARGS[@]}"
