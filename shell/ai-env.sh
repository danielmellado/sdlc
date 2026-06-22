#!/usr/bin/env bash
# Environment variables for AI SDLC workflow.
# Source this from your .bashrc:
#   source ~/Devel/openshift/sdlc/shell/ai-env.sh

export SDLC_ROOT="${SDLC_ROOT:-$HOME/Devel/openshift/sdlc}"
export EDITOR=nvim

# Claude Code: max parallel agents (keep it manageable)
export CLAUDE_MAX_SESSIONS=3

# Claude Code: enable agent teams (multi-agent collaboration)
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Claude Code: default model (uncomment to override)
# Available: opus, sonnet, haiku, fable, or full model IDs
# export ANTHROPIC_MODEL=sonnet

# Ensure tool paths are available
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
