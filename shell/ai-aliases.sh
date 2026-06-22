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
    local agents="${3:-1}"
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

    # Auto-install diffity commands if not already present
    if [[ ! -d "$project_dir/.claude/commands" ]] || ! ls "$project_dir/.claude/commands"/diffity-* &>/dev/null; then
        echo "Installing diffity commands in $project_dir..."
        (cd "$project_dir" && _sdlc_install_diffity_commands) || true
    fi

    # Set up shared coordination file for multi-agent sessions
    if [[ "$agents" -ge 2 ]]; then
        mkdir -p "$project_dir/.claude"
        cat > "$project_dir/.claude/team-status.md" <<'TEAMEOF'
# Agent Team Status

Shared coordination file. Each agent should:
1. Read this file at the start of every task
2. Update their section when starting/finishing work
3. Check for conflicts before modifying shared files
4. Note any blockers or handoffs needed

## Agent Roles
- **Agent 1 (top-right)**: Coder — implementation, core logic
- **Agent 2 (middle-right)**: Reviewer — review Agent 1's changes, catch issues, suggest improvements
- **Agent 3 (bottom-right)**: QE — write tests, verify behavior, check edge cases

## Current Tasks
| Agent | Status | Working on |
|-------|--------|------------|
| 1     | idle   |            |
| 2     | idle   |            |
| 3     | idle   |            |

## Coordination Notes
<!-- Agents: write notes here about shared state, conflicts, or handoffs -->

TEAMEOF

        # Add team instructions to CLAUDE.md if not already present
        if [[ ! -f "$project_dir/CLAUDE.md" ]]; then
            cat > "$project_dir/CLAUDE.md" <<'CLAUDEEOF'
# Project Instructions

## Multi-Agent Coordination

You are part of a team of agents working on this project simultaneously.
Read `.claude/team-status.md` before starting any task, and update it with
your current status. Check for conflicts before editing files another agent
may be working on.

If you see another agent is working on a file you need, note it in the
Coordination Notes section and work on something else until they're done.
CLAUDEEOF
        elif ! grep -qF "team-status.md" "$project_dir/CLAUDE.md" 2>/dev/null; then
            cat >> "$project_dir/CLAUDE.md" <<'CLAUDEEOF'

## Multi-Agent Coordination

You are part of a team of agents working on this project simultaneously.
Read `.claude/team-status.md` before starting any task, and update it with
your current status. Check for conflicts before editing files another agent
may be working on.

If you see another agent is working on a file you need, note it in the
Coordination Notes section and work on something else until they're done.
CLAUDEEOF
        fi
    fi

    local pane_cmd="$claude_cmd; echo 'Claude exited. Press enter to close.'; read"

    tmux new-session -d -s "$session_name" -c "$project_dir" "nvim ."
    tmux split-window -h -t "$session_name" -l 40% -c "$project_dir" "$pane_cmd"
    if [[ "$agents" -ge 2 ]]; then
        tmux split-window -v -t "$session_name:0.1" -c "$project_dir" "$pane_cmd"
    fi
    if [[ "$agents" -ge 3 ]]; then
        tmux split-window -v -t "$session_name:0.1" -c "$project_dir" "$pane_cmd"
    fi
    tmux select-pane -t "$session_name:0.0"
    tmux attach-session -t "$session_name"
}

# Multi-agent shortcuts
#   tmux-ai2 .              # nvim + 2 agents (coder + reviewer)
#   tmux-ai3 .              # nvim + 3 agents (coder + reviewer + QE)
#   tmux-ai3 . opus         # same with specific model
tmux-ai2() { tmux-ai "${1:-.}" "${2:-}" 2; }
tmux-ai3() { tmux-ai "${1:-.}" "${2:-}" 3; }

# --- Quick CI triage ---
ci-triage() {
    local pr_number="$1"
    if [[ -z "$pr_number" ]]; then
        echo "Usage: ci-triage <PR_NUMBER>"
        return 1
    fi
    npx gh-ci-artifacts "$pr_number"
}

# --- Install diffity as Claude Code slash commands ---
_sdlc_install_diffity_commands() {
    local tmpdir
    tmpdir="$(mktemp -d -p "${HOME}")"
    git clone --depth 1 https://github.com/kamranahmedse/diffity.git "$tmpdir" 2>/dev/null || {
        echo "Failed to clone diffity repo"
        rm -rf "$tmpdir"
        return 1
    }
    local skills_dir="$tmpdir/skills"
    if [[ -d "$skills_dir" ]]; then
        mkdir -p .claude/commands
        for skill_dir in "$skills_dir"/diffity-*; do
            local name
            name="$(basename "$skill_dir")"
            [[ -f "$skill_dir/SKILL.md" ]] && cp "$skill_dir/SKILL.md" ".claude/commands/${name}.md"
        done
        echo "Diffity commands installed in .claude/commands/"
    fi
    rm -rf "$tmpdir"
}

# --- Quick project setup with all AI tools ---
ai-init() {
    local project_dir="${1:-.}"
    cd "$project_dir" || return 1
    echo "Setting up AI tools in $(pwd)..."
    specify init . --ai claude 2>/dev/null || echo "speckit already initialized or not installed"
    _sdlc_install_diffity_commands
    echo "Done. Use 'tmux-ai .' to start coding."
}
