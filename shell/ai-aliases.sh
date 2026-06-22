#!/usr/bin/env bash
# Shell aliases and functions for AI SDLC workflow.
# Source this from your .bashrc:
#   source ~/Devel/openshift/sdlc/shell/ai-aliases.sh

SDLC_ROOT="${SDLC_ROOT:-$HOME/Devel/openshift/sdlc}"

# --- Sandboxed Claude Code ---
alias nono-claude="$SDLC_ROOT/nono/scripts/nono-claude.sh"
alias claudio="nono-claude"

# --- Model shortcuts (sandboxed) ---
alias claude-opus="nono-claude --model opus"
alias claude-sonnet="nono-claude --model sonnet"
alias claude-haiku="nono-claude --model haiku"

# --- Diffity shortcuts ---
alias dr="diffity"
alias drr="diffity --review"

# --- Quick speckit ---
alias spec-init="specify init . --ai claude"

# --- tmux-ai: open a tmux session with nvim + claude side by side ---
# Usage:
#   tmux-ai                   # current dir, default model
#   tmux-ai ~/project         # specific dir
#   tmux-ai ~/project opus    # specific dir + model
#   tmux-ai . sonnet          # current dir + model
tmux-ai() {
    local project_dir="${1:-.}"
    local model="${2:-}"
    project_dir="$(cd "$project_dir" && pwd)"
    local session_name
    session_name="ai-$(basename "$project_dir")"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux attach-session -t "$session_name"
        return
    fi

    local claude_cmd="$SDLC_ROOT/nono/scripts/nono-claude.sh"
    if [[ -n "$model" ]]; then
        claude_cmd="$claude_cmd --model $model"
    fi

    tmux new-session -d -s "$session_name" -c "$project_dir" "nvim ."
    tmux split-window -h -t "$session_name" -l 40% -c "$project_dir" "$claude_cmd"
    tmux select-pane -t "$session_name:0.0"
    tmux attach-session -t "$session_name"
}

# --- Quick CI triage ---
ci-triage() {
    local pr_number="$1"
    if [[ -z "$pr_number" ]]; then
        echo "Usage: ci-triage <PR_NUMBER>"
        return 1
    fi
    npx gh-ci-artifacts "$pr_number"
}

# --- Quick project setup with all AI tools ---
ai-init() {
    local project_dir="${1:-.}"
    cd "$project_dir" || return 1
    echo "Setting up AI tools in $(pwd)..."
    specify init . --ai claude 2>/dev/null || echo "speckit already initialized or not installed"
    npx skills add kamranahmedse/diffity 2>/dev/null || echo "diffity skills already installed or not available"
    echo "Done. Use 'tmux-ai .' to start coding."
}
