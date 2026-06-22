# Quickstart Guide

This guide walks you through your first AI-assisted coding session. It
assumes you've already run `make install` (or `make vm` + `make vm-ssh`
for a VM setup).

## The Three Layers

The toolkit has three layers of interaction, from outermost to innermost.
Each layer has its own keybindings -- they never conflict.

### Layer 1: tmux (window and pane management)

**Prefix: `Ctrl+b`** -- press it, release, then press the next key.

tmux manages your terminal layout. Think of it as a tiling window manager
for the terminal.

| Keys | What it does |
|------|-------------|
| `Ctrl+b a` | Open a sandboxed Claude Code pane |
| `Ctrl+b A` | Full AI layout (Neovim left, Claude right) |
| `Ctrl+b u` | Unsandboxed Claude (escape hatch) |
| `Ctrl+b c` | New tmux window |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b arrows` | Move between panes |
| `Ctrl+b n` / `Ctrl+b p` | Next / previous window |
| `Ctrl+b 0-9` | Jump to window by number |

### Layer 2: Neovim (code editing)

**Leader: `Space`** -- press it, then the next key(s). Wait a moment to
see the which-key menu with all options.

Neovim is your editor. It has LSP support, Git integration, and a Claude
Code panel built in.

| Keys | What it does |
|------|-------------|
| `Space a c` | Toggle Claude Code panel (sandboxed) |
| `Space a b` | Add current buffer to Claude's context |
| `Space a s` | Send visual selection to Claude |
| `Space f f` | Find files |
| `Space f g` | Live grep across project |
| `Space g g` | Git status |
| `Space g D` | Diff view |
| `Space l a` | LSP code action |
| `Space w` | Save file |
| `gd` | Go to definition |
| `K` | Hover docs |
| `Ctrl+n` | Toggle file tree |

Press `Space` and wait -- which-key shows all groups:
**f** = find, **g** = git, **l** = lsp, **a** = ai.

### Layer 3: Claude Code (AI agent)

Inside a Claude Code pane (either tmux or Neovim), you type natural language.
No special keys -- just describe what you want.

| Input | What it does |
|-------|-------------|
| (just type) | Ask Claude to do something |
| `/help` | Show all slash commands |
| `/caveman` | Enable token-saving mode |
| `/rc` | Toggle Remote Control (browser access) |
| `Esc` | Cancel current generation |

## Your First Session

### Step 1: Open a project

```bash
cd ~/workspace/my-project    # or any Git repo
tmux-ai .
```

This creates a tmux session with two panes:
- **Left**: Neovim with your project open
- **Right**: Claude Code, sandboxed via nono, ready for instructions

### Step 2: Talk to Claude

Click in the right pane (or `Ctrl+b` then right arrow) and type:

```
Look at this project and tell me what it does.
```

Claude reads the codebase and explains it. You can follow up with questions
or ask it to make changes.

### Step 3: Try a small task

```
Add a health check endpoint to the HTTP server.
```

Claude will:
1. Read the relevant files
2. Write the code
3. Show you what it changed

### Step 4: Review in Neovim

Switch to the left pane (`Ctrl+b` then left arrow):

- `Space g g` to see git status
- `Space g D` to open a diff view
- Browse changed files with `Space f f`

### Step 5: Use the Neovim Claude panel

While reading code in Neovim, you can send context to Claude:

1. Press `Space a c` to open the Claude panel inside Neovim
2. Select some code visually (`v` to start, move to select)
3. Press `Space a s` to send the selection to Claude
4. Ask "explain this" or "refactor this"

This Neovim Claude panel is also sandboxed through nono.

## Two Ways to Talk to Claude

| | tmux Claude pane | Neovim Claude panel |
|--|-------------------|---------------------|
| **What** | Full standalone CLI agent | Panel inside the editor |
| **Best for** | Big tasks, multi-file changes, feature work | Quick questions about code you're reading |
| **Context** | Reads files itself | You send it buffers/selections |
| **Open with** | `tmux-ai` or `Ctrl+b a` | `Space a c` |
| **Sandboxed** | Yes (nono) | Yes (nono) |
| **Use it** | 90% of the time | 10% for focused questions |

## Sandboxing

Every Claude entry point runs through `nono-claude.sh`, a wrapper that
launches Claude Code inside a [nono.sh](https://nono.sh) sandbox using
Landlock LSM (Linux kernel 6.7+).

**What Claude can access:**
- The current working directory (read + write)
- System libraries, SSL certs, DNS (`/usr`, `/lib`, `/etc/ssl`, etc.)
- Network: Anthropic API, GitHub, npm, PyPI, crates.io

**What Claude cannot access:**
- `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/.docker`, `~/.netrc`
- Arbitrary network hosts

**Escape hatches:**
- `Ctrl+b u` opens unsandboxed Claude in tmux
- Running `claude` directly bypasses the sandbox

## Model Selection

Different models for different tasks:

| Model | When to use | How to launch |
|-------|------------|---------------|
| Opus | Architecture, complex reasoning | `tmux-ai . opus` or `claude-opus` |
| Sonnet | Fast iteration, tests, small fixes | `tmux-ai . sonnet` or `claude-sonnet` |
| Haiku | Quick questions, classification | `claude-haiku` |
| Default | Whatever Anthropic sets as default | `tmux-ai .` or `nono-claude` |

All aliases are sandboxed. You can also set a persistent default:

```bash
# In shell/ai-env.sh, uncomment:
export ANTHROPIC_MODEL=sonnet
```

## Parallel Agents

Agent teams are enabled by default. You can run multiple Claude agents
in the same tmux session:

```bash
# Method 1: Split a pane and open another agent
# Ctrl+b "   (split horizontally)
nono-claude --model opus

# Method 2: Use tmux-ai which sets up the layout for you
tmux-ai . opus
```

Tell each agent a different task. They coordinate automatically.

A good pattern for a larger feature:
- Agent 1 (Opus): architecture and core implementation
- Agent 2 (Sonnet): writing tests
- Agent 3 (Sonnet): documentation and cleanup

## Remote Control

Access any Claude session from your browser at `claude.ai/code`:

```bash
nono-claude --rc           # launch with browser access
# or inside a running session:
/rc                        # toggle it on
```

A URL and QR code appear. The session runs on your machine; the browser is
just a window into it. Requires Claude Max subscription.

## Token Saving

Run `/caveman` at the start of each session. This enables compressed
communication that saves ~75% on token costs with no quality loss.

```
/caveman              # enable compression
/caveman-stats        # check savings
/caveman-compress     # compress CLAUDE.md (~46% input savings)
```

## What's Next

- [Full workflow reference](workflow.md) -- detailed guide for every tool
- [README](../README.md) -- project overview, toolchain, requirements
- [VM setup](../vm/README.md) -- provisioning clean development environments
