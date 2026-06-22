# sdlc - AI-Assisted Software Development Lifecycle Toolkit

A monorepo containing a complete AI-assisted development workflow for
OpenShift/Go projects: neovim config, tmux setup, nono.sh sandbox profiles,
Claude Code CLI integration, speckit/diffity/caveman tooling, CI triage, and
PR review skills.

**New here?** Start with the [Quickstart Guide](docs/quickstart.md).

## Quick Start

```bash
git clone git@github.com:dmellado/sdlc.git ~/Devel/openshift/sdlc
cd ~/Devel/openshift/sdlc
make install
```

This will:
1. Install required tools (nono, claude-code, speckit, diffity, caveman, gh-ci-artifacts)
2. Symlink neovim config to `~/.config/nvim/`
3. Symlink tmux config to `~/.tmux.conf`
4. Source shell aliases into your bashrc
5. Install Claude Code skills and plugins

### Clean VM Install

Provision a fresh Fedora VM with everything pre-configured:

```bash
make vm                   # create VM (auto-injects host configs)
make vm-ssh               # SSH in
cd ~/cluster-monitoring-operator
tmux-ai .                 # start working
```

The VM comes with all tools installed and your Claude/git/gh auth
copied from the host. See [vm/README.md](vm/README.md) for details.

## What's Inside

| Directory | Purpose |
|-----------|---------|
| `nvim/` | Full Neovim config with lazy.nvim, LSP, treesitter, and Claude Code integration |
| `tmux/` | Enhanced tmux config with AI workflow layouts |
| `shell/` | Shell aliases and environment variables for AI tools |
| `nono/` | nono.sh sandbox profiles for running Claude Code safely |
| `tools/` | Installation scripts for all external tools |
| `skills/` | Claude Code custom skills for CI triage, PR triage, and code review |
| `vm/` | VM provisioning scripts (libvirt/cloud-init) for clean environments |
| `docs/` | [Quickstart](docs/quickstart.md) and [workflow reference](docs/workflow.md) |

## Toolchain

| Tool | Purpose |
|------|---------|
| [nono.sh](https://nono.sh) | Kernel-level sandbox (Landlock) for AI agent isolation |
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Primary AI coding agent |
| [speckit](https://github.com/github/spec-kit) | Spec-driven development workflow |
| [diffity](https://github.com/kamranahmedse/diffity) | Diff review with AI annotations |
| [caveman](https://github.com/JuliusBrussee/caveman) | Token reduction (~75%) |
| [gh-ci-artifacts](https://github.com/jmchilton/gh-ci-artifacts) | CI failure artifact collection and analysis |
| [claudecode.nvim](https://github.com/coder/claudecode.nvim) | Neovim <-> Claude Code MCP bridge |

## Requirements

- Fedora 44+ (kernel 6.7+ for full Landlock fs+network sandboxing)
- Neovim >= 0.10.0
- Node.js >= 20 (for Claude Code CLI, diffity)
- Go (GOTOOLCHAIN=auto is set, so tools like gopls auto-download the required version)
- Python 3.11+ with uv (for speckit)
- tmux
- gh (GitHub CLI)

## Sandboxing

**Everything runs sandboxed by default.** There is no unsandboxed Claude unless
you explicitly ask for it.

- `tmux-ai` launches Claude Code through `nono-claude.sh`
- `prefix+a` in tmux launches a sandboxed Claude pane
- `Space a c` in Neovim launches Claude through the same `nono-claude.sh` wrapper
- Shell aliases (`claude-opus`, `claude-sonnet`, `claude-haiku`) are all sandboxed

The only escape hatch is `prefix+u` in tmux or running `claude` directly.

The nono profile extends the built-in `claude-code` profile and additionally
denies access to `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, and `~/.docker`.

## Workflow

### 1. Start a session

```bash
cd ~/workspace/my-project
tmux-ai .                 # default model
tmux-ai . opus            # use Opus (heavy reasoning)
tmux-ai . sonnet          # use Sonnet (fast/cheap)
```

This opens Neovim (left) + sandboxed Claude Code (right) with agent teams enabled.

### 2. Save tokens

In the Claude pane, type `/caveman` once at the start. Saves ~75% on token costs.

### 3. Do the work

**Small fix** -- just describe it:

```
The reconciler doesn't handle missing secrets. Fix it.
```

**Bigger feature** -- use speckit for structure:

```
/speckit.specify     # describe what you want
/speckit.plan        # get a technical plan
/speckit.implement   # execute it
```

**Parallel work** -- split the tmux pane and open another agent:

```bash
# prefix + "  (split pane), then:
nono-claude --model opus       # heavy reasoning agent
nono-claude --model sonnet     # fast iteration agent
# or just: claude-opus / claude-sonnet
```

Tell each agent a different task. They work simultaneously.

### 4. Review before committing

```
/diffity-review      # Claude reviews its own diff
```

Or in Neovim: `Space gg` (git status), `Space gD` (diff view).

### 5. Triage CI failures

```
/triage-ci 1234      # analyze failed CI for PR #1234
```

### Cheat sheet

| When | Do | Why |
|------|----|-----|
| Start of session | `/caveman` | Save tokens |
| Small fix | Just describe it | Claude does the rest |
| Big feature | `/speckit.specify` -> `.plan` -> `.implement` | Structured approach |
| Parallel work | New pane + `nono-claude` | Two agents at once |
| Before commit | `/diffity-review` | Catch mistakes |
| CI is red | `/triage-ci <PR>` | Auto-diagnose |
| Review a PR | `/triage-pr <PR>` | Quick classification |

For the full reference, see [docs/workflow.md](docs/workflow.md).
For a guided introduction, see [docs/quickstart.md](docs/quickstart.md).

### Remote Control (browser access)

Control any Claude session from your host browser at `claude.ai/code`:

```bash
nono-claude --rc               # launch with browser access
# or inside a running session: /rc
```

Requires Claude Max subscription. The session stays on the VM; the browser is just a window.

### Escape hatches

- Everything uses nono (sandboxed) by default: `tmux-ai`, `prefix+a`, `prefix+A`, Neovim `<leader>ac`
- For unsandboxed Claude: `prefix+u` or run `claude` directly

## License

MIT
