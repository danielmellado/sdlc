#!/usr/bin/env bash
# Install all external tools for the AI SDLC workflow.
# Idempotent: skips tools that are already installed.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

check_cmd() {
    command -v "$1" &>/dev/null
}

# --- Neovim ---
install_neovim() {
    if check_cmd nvim; then
        info "neovim already installed: $(nvim --version | head -1)"
        return
    fi
    warn "Installing neovim..."
    if check_cmd dnf; then
        sudo dnf install -y neovim
    else
        err "Cannot install neovim: dnf not found. Install manually."
        return 1
    fi
}

# --- Node.js (required for Claude Code, diffity) ---
install_node() {
    if check_cmd node; then
        info "node already installed: $(node --version)"
        return
    fi
    warn "Installing Node.js..."
    if check_cmd dnf; then
        sudo dnf install -y nodejs npm
    else
        err "Cannot install node: dnf not found. Install manually."
        return 1
    fi
}

# --- nono (kernel-level sandbox) ---
install_nono() {
    if check_cmd nono; then
        info "nono already installed: $(nono --version 2>/dev/null || echo 'installed')"
        return
    fi
    warn "Installing nono..."
    if check_cmd cargo; then
        cargo install nono-cli
    elif check_cmd brew; then
        brew install nono
    else
        err "Cannot install nono: need cargo or brew. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        return 1
    fi
}

# --- Claude Code CLI ---
install_claude_code() {
    if check_cmd claude; then
        info "claude-code already installed"
        return
    fi
    warn "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
}

# --- uv (Python package manager, required for speckit) ---
install_uv() {
    if check_cmd uv; then
        info "uv already installed: $(uv --version)"
        return
    fi
    warn "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
}

# --- speckit ---
install_speckit() {
    if check_cmd specify; then
        info "speckit already installed"
        return
    fi
    warn "Installing speckit..."
    uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git"
}

# --- diffity ---
install_diffity() {
    if check_cmd diffity; then
        info "diffity already installed"
        return
    fi
    warn "Installing diffity..."
    npm install -g diffity
}

# --- gh CLI ---
install_gh() {
    if check_cmd gh; then
        info "gh already installed: $(gh --version | head -1)"
        return
    fi
    warn "Installing GitHub CLI..."
    if check_cmd dnf; then
        sudo dnf install -y gh
    else
        err "Cannot install gh: dnf not found. Install manually."
        return 1
    fi
}

# --- Run all ---
main() {
    info "=== AI SDLC Tool Installer ==="
    echo

    install_neovim
    install_node
    install_nono
    install_claude_code
    install_uv
    install_speckit
    install_diffity
    install_gh

    echo
    info "=== Tool installation complete ==="
    echo
    info "Post-install steps (run manually):"
    echo "  1. caveman:         claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman"
    echo "  2. gh-ci-artifacts: npx gh-ci-artifacts <PR_NUMBER> (runs via npx, no global install needed)"
    echo "  3. speckit init:    cd <project> && specify init . --ai claude"
    echo "  4. diffity skills:  cd <project> && npx skills add kamranahmedse/diffity"
}

main "$@"
