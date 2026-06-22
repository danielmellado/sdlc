#!/usr/bin/env bash
# Provisioning script that runs inside the VM as the 'dev' user.
# Called by cloud-init after packages are installed.
set -euo pipefail

export HOME="/home/dev"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
cd "$HOME"

echo "=== AI SDLC VM Provisioning ==="

# --- Clone the sdlc repo ---
if [[ ! -d "$HOME/sdlc" ]]; then
    echo "[+] Cloning sdlc repo..."
    git clone https://github.com/dmellado/sdlc.git "$HOME/sdlc" 2>/dev/null || {
        echo "[!] Could not clone from GitHub, copying from /opt if available"
        mkdir -p "$HOME/sdlc"
    }
fi

# --- Install uv (Python package manager) ---
if ! command -v uv &>/dev/null; then
    echo "[+] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# --- Install nono (kernel sandbox) ---
if ! command -v nono &>/dev/null; then
    echo "[+] Installing nono..."
    cargo install nono-cli 2>/dev/null || echo "[!] nono install failed, may need manual install"
fi

# --- Pull nono's built-in Claude profile (needed by extends: "claude-code") ---
echo "[+] Pulling nono claude profile..."
NONO_AUTO_MIGRATE=1 nono pull always-further/claude 2>/dev/null || echo "[!] nono profile pull failed"

# --- Install Claude Code CLI ---
if ! command -v claude &>/dev/null; then
    echo "[+] Installing Claude Code CLI..."
    mkdir -p "$HOME/.local"
    npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local"
fi

# --- Install speckit ---
if ! command -v specify &>/dev/null; then
    echo "[+] Installing speckit..."
    uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git" 2>/dev/null || echo "[!] speckit install failed"
fi

# --- Install diffity ---
if ! command -v diffity &>/dev/null; then
    echo "[+] Installing diffity..."
    npm install -g diffity --prefix "$HOME/.local"
fi

# --- Deploy sdlc config ---
echo "[+] Deploying neovim config..."
mkdir -p "$HOME/.config"
ln -sfn "$HOME/sdlc/nvim" "$HOME/.config/nvim"

echo "[+] Deploying tmux config..."
ln -sf "$HOME/sdlc/tmux/tmux.conf" "$HOME/.tmux.conf"

echo "[+] Deploying nono-claude wrapper..."
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/sdlc/nono/scripts/nono-claude.sh" "$HOME/.local/bin/nono-claude"

echo "[+] Adding shell integration..."
if ! grep -qF "sdlc/shell/ai-env.sh" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'BASHEOF'

# AI SDLC toolkit
source ~/sdlc/shell/ai-env.sh
source ~/sdlc/shell/ai-aliases.sh
BASHEOF
fi

# --- Set up workspace directory ---
mkdir -p "$HOME/workspace"

# --- Bootstrap neovim plugins ---
echo "[+] Bootstrapping neovim plugins (headless)..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || echo "[!] Neovim plugin sync failed (will retry on first launch)"

echo "=== Provisioning complete ==="
echo ""
echo "Usage:"
echo "  tmux-ai ~/workspace       # Start AI coding session"
echo "  nono-claude                # Sandboxed Claude Code"
echo "  claude                     # Claude Code (unsandboxed)"
