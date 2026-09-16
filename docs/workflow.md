# AI SDLC Workflow Guide

How all the pieces fit together for AI-assisted development on
OpenShift/Go projects.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                              tmux                                    │
│  ┌────────────────────────┐  ┌───────────────────────────────────┐   │
│  │       Neovim           │  │  Agent 1 (coder)                 │   │
│  │                        │  │  Claude Code OR OpenCode         │   │
│  │  ┌──────────────────┐  │  │  Sandboxed via nono.sh           │   │
│  │  │ claudecode.nvim  │◄─┼──┤  Skills: /speckit.* /scan-cves   │   │
│  │  │  (MCP bridge)    │  │  │         /diffity-review          │   │
│  │  │  also sandboxed  │  │  ├───────────────────────────────────┤   │
│  │  └──────────────────┘  │  │  Agent 2 (reviewer)              │   │
│  │                        │  │  Skills: /review-patterns         │   │
│  │  LSP: gopls, pyright   │  │         /triage-pr               │   │
│  │  Lint: golangci-lint   │  ├───────────────────────────────────┤   │
│  │  Format: conform.nvim  │  │  Agent 3 (QE)                    │   │
│  │  Git: gitsigns,        │  │  Skills: /triage-ci /caveman     │   │
│  │       fugitive         │  │                                   │   │
│  └────────────────────────┘  └───────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
          │                           │
          ▼                           ▼
    ┌───────────┐            ┌────────────────┐      ┌──────────────┐
    │  diffity  │            │ gh-ci-artifacts│      │ Quay/skopeo  │
    │ (browser) │            │   (CI logs)    │      │ (CVE scans)  │
    └───────────┘            └────────────────┘      └──────────────┘
```

Agent panes can run either **Claude Code** (default) or **OpenCode** (open
source alternative). Both are sandboxed via nono. OpenCode also supports
local LLMs through Ollama for fully offline/private development.

## Daily Workflow

### 1. Starting a Coding Session

```bash
# Option A: Full AI layout (neovim + sandboxed Claude Code side by side)
tmux-ai ~/Devel/openshift/my-project
tmux-ai ~/Devel/openshift/my-project opus     # with a specific model
tmux-ai ~/Devel/openshift/my-project sonnet   # cheaper/faster model

# Option B: Multi-agent layout (nvim + 2 or 3 Claude panes)
tmux-ai2 ~/Devel/openshift/my-project         # nvim + 2 agents
tmux-ai3 ~/Devel/openshift/my-project opus    # nvim + 3 agents (coder/reviewer/QE)

# Option C: Just open neovim, launch Claude Code later
cd ~/Devel/openshift/my-project
nvim .
# In tmux: press prefix+a to open sandboxed Claude Code in right pane
# Or prefix+u for an unsandboxed session (escape hatch)

# Option D: Use OpenCode instead of Claude Code
tmux-ai ~/Devel/openshift/my-project --opencode    # sandboxed OpenCode
tmux-ai ~/Devel/openshift/my-project --oc           # short form
tmux-ai2 ~/Devel/openshift/my-project --opencode    # nvim + 2 OpenCode agents

# Option E: Local LLM via OpenCode + Ollama (fully offline)
tmux-ai ~/Devel/openshift/my-project --local        # OpenCode + Ollama
# In tmux: press prefix+O for OpenCode with Ollama in right pane
```

`tmux-ai` launches Claude Code by default, or OpenCode with `--opencode`/`--oc`.
Both run inside a nono sandbox. Agent teams are enabled globally for Claude Code
sessions, so you can spawn sub-agents from any session.

Model shortcuts for standalone use:

```bash
# Claude Code (sandboxed)
claude-opus                # sandboxed Opus
claude-sonnet              # sandboxed Sonnet
claude-haiku               # sandboxed Haiku
nono-claude --model opus   # equivalent long form

# OpenCode (sandboxed)
nono-opencode              # sandboxed OpenCode (uses configured provider)
oc-ai                      # alias for nono-opencode
ai-local                   # sandboxed OpenCode + Ollama (local LLM)
```

Inside Neovim, `<leader>ac` (Space a c) also opens Claude Code via
`claudecode.nvim`. This too launches through `nono-claude.sh`, so it is
sandboxed. Claude Code can read your open buffers, see diagnostics, and
show diffs directly in Neovim via the MCP WebSocket bridge.

### Local LLM Support (Ollama via OpenCode)

For fully offline or private development, use OpenCode with Ollama as the
LLM backend. No API keys or cloud access needed.

```bash
# Install Ollama and pull a model
ollama pull qwen2.5-coder:32b    # or any model you prefer

# Launch OpenCode with Ollama
ai-local                         # standalone
tmux-ai . --local                # in tmux layout
# Or in tmux: prefix+O
```

Configure the default model in OpenCode's config (`~/.config/opencode/opencode.json`)
or via the `/models` command inside OpenCode's TUI. OpenCode supports any
OpenAI-compatible local server, so alternatives like LM Studio or vLLM work
too -- just set the provider `baseURL` in the config.

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

For larger features, there are two multi-agent modes:

#### Mode 1: Agent Teams (default — single session with sub-agents)

This is what `tmux-ai .` gives you out of the box. One Claude session that
can spawn and manage sub-agents internally. You describe the feature and
Claude delegates — a coding agent, a test agent, a reviewer — all coordinated
through the parent.

```bash
tmux-ai . opus
# Then: "Implement X. Use agent teams: one coder, one reviewer, one QE."
```

No extra panes needed — Claude manages everything within the single session.
Best for well-defined features where you want hands-off coordination. The env
var `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (enabled by default) powers this.

#### Mode 2: Multi-pane (independent sessions with shared coordination)

Multiple Claude sessions in tmux panes, each with its own role. They coordinate
via a shared `.claude/team-status.md` file — each agent reads it before starting
work and updates it with their status.

```bash
tmux-ai3 . opus               # nvim + 3 agents
tmux-ai2 .                    # nvim + 2 agents
```

You steer each pane directly:
- Pane 1: "You are the coder. Implement X. Update team-status.md."
- Pane 2: "You are the reviewer. Watch git changes and review them."
- Pane 3: "You are QE. Write tests for whatever Agent 1 implements."

Best for exploratory work, mixed models (opus for reasoning + sonnet for
iteration), or when you want direct control over each agent.

#### Choosing between modes

| Situation | Mode | Why |
|-----------|------|-----|
| Large well-defined feature | Agent Teams | Less manual coordination |
| Exploratory / iterative | Multi-pane | You steer each agent |
| Mixed models (opus + sonnet) | Multi-pane | Different model per pane |
| Quick parallel tasks | Multi-pane | No planning overhead |

In both cases, keep it to ~3 agents max. Beyond that it becomes hard to review
what each one produces before moving forward.

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

### 8. Scanning Container Images for CVEs

Scan container images for known vulnerabilities. Two backends are supported:

- **Quay/Clair** (default): skopeo + Quay security API. Best for Quay-hosted images.
- **ACS/roxctl**: Red Hat Advanced Cluster Security scanner. Works with any
  registry and is the Konflux-standard backend (migrating from clair-scan to
  roxctl-scan).

#### Shell command (no LLM needed)

```bash
# Quay/Clair backend (default)
scan-cves quay.io/openshift/ose-cli:v4.16
scan-cves quay.io/openshift/ose-cli:v4.16 --severity high

# ACS/roxctl backend (any registry)
export ROX_ENDPOINT=central.stackrox.svc:443
export ROX_API_TOKEN=<token>
scan-cves quay.io/openshift/ose-cli:v4.16 --roxctl
scan-cves registry.redhat.io/ubi9:latest --roxctl --severity critical
```

The Quay backend uses skopeo to get the manifest digest and queries the Quay
security API (Clair scanner). The roxctl backend delegates to ACS Central,
which is the same scanner used by Konflux `roxctl-scan` pipeline tasks.

For private Quay images, set `QUAY_TOKEN` in your environment:

```bash
export QUAY_TOKEN="your-quay-oauth-token"
scan-cves quay.io/myorg/private-image:latest
```

#### Claude Code skill (AI-assisted analysis)

```
/scan-cves quay.io/openshift/ose-cli:v4.16
/scan-cves quay.io/openshift/ose-cli:v4.16 --roxctl
```

The skill does everything the shell command does, plus:
- Cross-references with Red Hat Security Data API for RHSA advisories
- Checks if newer image tags fix the critical/high CVEs
- Handles multi-arch manifest lists
- Provides actionable remediation recommendations
- With `--roxctl`, also runs `roxctl image check` for Konflux policy violations

## Keybindings Reference

### Neovim (leader = Space)

| Key | Action |
|-----|--------|
| `Space a c` | Open Claude Code (sandboxed via nono) |
| `Space a b` | Add current buffer to Claude context |
| `Space a s` (visual) | Send selection to Claude |
| `Space f f` | Find files (Telescope) |
| `Space f g` | Live grep (Telescope) |
| `Space f b` | Buffers (Telescope) |
| `Space f s` | Document symbols |
| `Ctrl+n` | Toggle file explorer (Neo-tree) |
| `F3` | Toggle symbols outline |
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover documentation |
| `Space l a` | Code action |
| `Space l r` | Rename symbol |
| `Space l f` | Format buffer |
| `Space g g` | Git status (fugitive) |
| `Space g b` | Git blame |
| `Space g D` | Diffview open |
| `]h` / `[h` | Next/previous git hunk |
| `]d` / `[d` | Next/previous diagnostic |
| `Space w` | Save file |
| `Space e` | Show diagnostic popup |

Press `Space` and wait for the which-key menu to see all available groups.

### tmux (prefix = Ctrl+b)

| Key | Action |
|-----|--------|
| `prefix a` | Open sandboxed Claude Code in right pane |
| `prefix A` | Full AI layout (nvim left, sandboxed Claude right) |
| `prefix u` | Open unsandboxed Claude Code (escape hatch) |
| `prefix o` | Open sandboxed OpenCode in right pane |
| `prefix O` | Open sandboxed OpenCode + Ollama (local LLM) |
| `prefix e` | Toggle broadcast to all panes |
| `prefix c` | New tmux window (tmux default) |
| `prefix "` | Split pane horizontally |
| `prefix %` | Split pane vertically |
| `prefix arrows` | Move between panes |
| `prefix 0-9` | Switch to window by number |

### Shell

| Command | Action |
|---------|--------|
| `tmux-ai <dir> [model]` | Open AI tmux session (nvim + 1 Claude agent) |
| `tmux-ai <dir> --opencode` | Open AI tmux session with OpenCode |
| `tmux-ai <dir> --local` | Open AI tmux session with OpenCode + Ollama |
| `tmux-ai2 <dir> [model]` | nvim + 2 agents (coder + reviewer) |
| `tmux-ai3 <dir> [model]` | nvim + 3 agents (coder + reviewer + QE) |
| `nono-claude` | Launch sandboxed Claude Code |
| `nono-claude --model opus` | Sandboxed Claude with specific model |
| `nono-claude --rc` | Sandboxed Claude with Remote Control (browser access) |
| `claude-opus` / `claude-sonnet` / `claude-haiku` | Model shortcut aliases |
| `claudio` | Alias for `nono-claude` |
| `nono-opencode` | Launch sandboxed OpenCode |
| `oc-ai` | Alias for `nono-opencode` |
| `ai-local` | OpenCode + Ollama (local LLM, sandboxed) |
| `ci-triage <PR>` | Download and analyze CI failures |
| `scan-cves <image>` | Scan Quay image for CVEs |
| `ai-init <dir>` | Set up speckit + diffity in a project |
| `spec-init` | Quick `specify init . --ai claude` |

## Sandbox Security Model

nono.sh uses Landlock LSM (Linux kernel 6.7+) to enforce:

- **Filesystem**: AI agents can only access the current working directory
  and explicitly allowed paths. `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`,
  `~/.docker` are blocked by default.
- **Network**: Provider-specific allowlists. Claude Code extends nono's built-in
  `claude-code` profile (Anthropic API, GitHub, registries). OpenCode has a
  custom profile allowing multiple providers (Anthropic, OpenAI, Google, Ollama
  on localhost, OpenCode Zen).
- **Irrevocable**: Once applied, the sandbox cannot be loosened, even by the
  sandboxed process itself.

Two nono profiles are provided:

| Profile | File | Used by |
|---------|------|---------|
| Claude Code | `nono/claude-code.json` | `nono-claude`, `tmux-ai`, `prefix+a`, claudecode.nvim |
| OpenCode | `nono/opencode.json` | `nono-opencode`, `tmux-ai --oc`, `prefix+o` |

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
copied from the host. GOTOOLCHAIN=auto is set so tools like gopls
auto-download the Go version they need. See [../vm/README.md](../vm/README.md)
for details.
