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

# OpenCode: default provider and model (uncomment to override)
# Providers: anthropic, openai, google, ollama, opencode (Zen)
# export OPENCODE_PROVIDER=anthropic
# export OPENCODE_MODEL=claude-sonnet-4-20250514

# Ollama: remote GPU box (RTX 5070 Ti)
export OLLAMA_HOST=http://192.168.1.58:11434

# Quay.io token for private image CVE scanning (optional)
# export QUAY_TOKEN=""

# ACS / roxctl for image scanning (Konflux roxctl-scan backend)
# Required when using: scan-cves <image> --roxctl
# export ROX_ENDPOINT="central.stackrox.svc:443"
# export ROX_API_TOKEN=""

# Go toolchain: auto-download newer Go when required by tools like gopls
export GOTOOLCHAIN=auto

# Ensure tool paths are available
export PATH="$HOME/go/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
