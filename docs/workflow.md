# AI SDLC Workflow Guide

How all the pieces fit together for AI-assisted development on
OpenShift/Go projects.

## Architecture

```
┌───────────────────────────────────────────────────── ─ ───┐
│                        tmux                               │
│  ┌───────────────────── ─┐  ┌─────────────────────── ──┐  │
│  │       Neovim          │  │     Claude Code CLI      │  │
│  │                       │  │                          │  │
│  │  ┌────────────── ──┐  │  │  Sandboxed via nono.sh   │  │
│  │  │ claudecode.nvim │◄─┼──┤  (Landlock kernel LSM)   │  │
│  │  │  (MCP bridge)   │  │  │                          │  │
│  │  └────────────────┘   │  │  Skills:                 │  │
│  │                       │  │  - /triage-ci            │  │
│  │  LSP: gopls, pyright  │  │  - /triage-pr            │  │
│  │  Lint: golangci-lint  │  │  - /review-patterns      │  │
│  │  Format: conform.nvim │  │  - /caveman              │  │
│  │  Git: gitsigns,       │  │  - /diffity-review       │  │
│  │       fugitive        │  │  - /speckit.*            │  │
│  └─────────────────── ───┘  └─────────────────────── ──┘  │
└─────────────────────────────────────────────────────  ────┘
          │                           │
          ▼                           ▼
    ┌───────────┐            ┌─────────  ─────┐
    │  diffity  │            │ gh-ci-artifacts│
    │ (browser) │            │   (CI logs)    │
    └───────────┘            └───────────  ───┘
```

## Daily Workflow

### 1. Starting a Coding Session

```bash
# Option A: Full AI layout (neovim + sandboxed Claude Code side by side)
tmux-ai ~/Devel/openshift/my-project
tmux-ai ~/Devel/openshift/my-project opus     # with a specific model
tmux-ai ~/Devel/openshift/my-project sonnet   # cheaper/faster model

# Option B: Just open neovim, launch Claude Code later
cd ~/Devel/openshift/my-project
nvim .
# In tmux: press prefix+S to open sandboxed Claude Code in right pane
# Or prefix+C for an unsandboxed session (escape hatch)
```

`tmux-ai` always launches Claude Code inside a nono sandbox by default.
Agent teams are enabled globally, so you can spawn sub-agents from any session.

Model shortcuts for standalone use:

```bash
claude-opus                # sandboxed Opus
claude-sonnet              # sandboxed Sonnet
claude-haiku               # sandboxed Haiku
nono-claude --model opus   # equivalent long form
```

Inside neovim, `<leader>ac` also opens Claude Code via `claudecode.nvim`.
Claude Code can read your open buffers, see diagnostics, and show diffs
directly in neovim via the MCP WebSocket bridge.

### 2. Adding a New Feature (Spec-Driven)

For anything beyond a trivial change, use speckit to structure your work:

```bash
# First time in a project:
ai-init .

# Then in Claude Code:
/speckit.specify     # Define what you want to build
/speckit.plan        # Create technical implementation plan
/speckit.tasks       # Generate actionable task list
/speckit.implement   # Execute tasks
/speckit.converge    # Check progress, add remaining work
```

For larger features, use agent teams (enabled by default) with different models:

```bash
# In tmux, split panes and run different agents:
nono-claude --model opus       # heavy reasoning for architecture
nono-claude --model sonnet     # fast iteration for tests
```

A good ratio: 3 coding agents, 1 reviewer, 1 QE agent writing tests.

### 3. Reviewing Generated Code

After Claude generates code, review it before committing:

```bash
# In Claude Code:
/diffity-review              # AI reviews the diff, leaves inline comments
# Open browser to see annotated diff
/diffity-resolve             # Apply fixes from comments
```

Or manually in the diffity browser UI:
1. Open the diff viewer
2. Leave comments on lines you want changed
3. Run `/diffity-resolve` to have Claude apply your feedback

### 4. Reducing Token Usage

Enable caveman mode at the start of every Claude Code session:

```
/caveman              # Default: full compression (~75% token savings)
/caveman-compress     # Compress CLAUDE.md to save input tokens (~46%)
/caveman-stats        # Check your token savings
```

### 5. Triaging CI Failures

When a PR's CI fails:

```
/triage-ci 1234
```

This will:
1. Download all failed run artifacts via `gh-ci-artifacts`
2. Parse Go test output, Ginkgo failures, JUnit XML
3. Correlate logs across components to find the root cause
4. Suggest a fix or flag it as a flaky test

Even when the root cause analysis is wrong, the context is loaded and you
can ask follow-up questions interactively.

### 6. Triaging Incoming PRs

For a quick classification of incoming PRs:

```
/triage-pr 5678
```

Classifications:
- **MERGEABLE**: Ready to review and merge
- **NEEDS-WORK**: Has specific issues (listed)
- **NEEDS-DISCUSSION**: Architectural questions to resolve first
- **STALE**: Needs a rebase or author attention
- **WIP**: Still in progress

### 7. Code Review with Patterns

When reviewing Go/OpenShift code:

```
/review-patterns             # Review working tree changes
/review-patterns main..HEAD  # Review branch changes
```

Checks for: error handling, naming conventions, concurrency issues,
Kubernetes-specific patterns (RBAC, deep-copy, finalizers), and test quality.

## Keybindings Reference

### Neovim

| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<leader>ac` | Open Claude Code |
| `<leader>ab` | Add current buffer to Claude |
| `<leader>as` (visual) | Send selection to Claude |
| `<leader>ff` | Find files (Telescope) |
| `<leader>fg` | Live grep (Telescope) |
| `<leader>fb` | Buffers (Telescope) |
| `<leader>fs` | Document symbols |
| `<C-n>` | Toggle file explorer (Neo-tree) |
| `<F3>` | Toggle symbols outline |
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover documentation |
| `<leader>la` | Code action |
| `<leader>lr` | Rename symbol |
| `<leader>lf` | Format buffer |
| `<leader>gg` | Git status (fugitive) |
| `<leader>gb` | Git blame |
| `<leader>gD` | Diffview open |
| `]h` / `[h` | Next/previous git hunk |
| `]d` / `[d` | Next/previous diagnostic |

### tmux

| Key | Action |
|-----|--------|
| `prefix + C` | Open Claude Code in right pane |
| `prefix + S` | Open sandboxed Claude Code (nono) |
| `prefix + A` | Full AI layout (nvim left, Claude right) |
| `prefix + e` | Toggle broadcast to all panes |

### Shell

| Command | Action |
|---------|--------|
| `tmux-ai <dir> [model]` | Open AI tmux session (optional model: opus, sonnet, haiku) |
| `nono-claude` | Launch sandboxed Claude Code |
| `nono-claude --model opus` | Sandboxed Claude with specific model |
| `nono-claude --rc` | Sandboxed Claude with Remote Control (browser access) |
| `claude-opus` / `claude-sonnet` / `claude-haiku` | Model shortcut aliases |
| `claudio` | Alias for `nono-claude` |
| `ci-triage <PR>` | Download and analyze CI failures |
| `ai-init <dir>` | Set up speckit + diffity in a project |
| `spec-init` | Quick `specify init . --ai claude` |

## Sandbox Security Model

nono.sh uses Landlock LSM (Linux kernel 6.7+) to enforce:

- **Filesystem**: Claude Code can only access the current working directory
  and explicitly allowed paths. `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`
  are blocked by default.
- **Network**: Only allowed domains (Anthropic API, GitHub, package registries)
  can be contacted. No data exfiltration possible.
- **Irrevocable**: Once applied, the sandbox cannot be loosened, even by the
  sandboxed process itself.

Zero startup overhead and no image management, while maintaining strong
kernel-level isolation.

## Remote Control (Browser Access)

Control any Claude Code session from your host browser at `claude.ai/code`
or the Claude mobile app. The session stays on the VM/machine; the browser
is just a remote view into it.

```bash
# Launch with browser access:
nono-claude --rc

# Or enable it inside a running session:
/rc
```

A URL and QR code appear in the terminal. Open the URL in any browser,
or scan the QR code with the Claude mobile app.

Requirements: Claude Max subscription, Claude Code v2.1.52+.

## VM-Based Workflow

For full isolation or clean reproducible environments, provision a VM:

```bash
make vm                   # create VM (auto-injects host configs)
make vm-ssh               # SSH in
tmux-ai . opus            # start working with Opus
```

The VM comes pre-configured with all tools, configs, and your Claude/git auth
copied from the host. See [../vm/README.md](../vm/README.md) for details.
