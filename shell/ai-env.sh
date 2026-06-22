#!/usr/bin/env bash
# Environment variables for AI SDLC workflow.
# Source this from your .bashrc:
#   source ~/Devel/openshift/sdlc/shell/ai-env.sh

if [[ -z "$SDLC_ROOT" ]]; then
    # Auto-detect from this script's location
    _sdlc_self="${BASH_SOURCE[0]:-$0}"
    if [[ -L "$_sdlc_self" ]]; then _sdlc_self="$(readlink -f "$_sdlc_self")"; fi
    export SDLC_ROOT="$(cd "$(dirname "$_sdlc_self")/.." && pwd)"
    unset _sdlc_self
fi
export EDITOR=nvim

# Claude Code: max parallel agents (keep it manageable)
export CLAUDE_MAX_SESSIONS=3

# Claude Code: enable agent teams (multi-agent collaboration)
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Claude Code: default model (uncomment to override)
# Available: opus, sonnet, haiku, fable, or full model IDs
# export ANTHROPIC_MODEL=sonnet

# Go toolchain: auto-download newer Go when required by tools like gopls
export GOTOOLCHAIN=auto

# Ensure tool paths are available
export PATH="$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
