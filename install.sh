#!/usr/bin/env bash
# Master installer for the AI SDLC toolkit.
# Idempotent: safe to run multiple times.
#
# Usage:
#   ./install.sh          # Full install (symlinks + tools)
#   ./install.sh link     # Only create symlinks
#   ./install.sh tools    # Only install tools
set -euo pipefail

SDLC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

backup_and_link() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" ]]; then
        local current_target
        current_target="$(readlink -f "$dst")"
        if [[ "$current_target" == "$(readlink -f "$src")" ]]; then
            info "Already linked: $dst -> $src"
            return
        fi
        warn "Updating symlink: $dst"
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        warn "Backing up existing $dst to ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    info "Linked: $dst -> $src"
}

do_links() {
    info "=== Creating symlinks ==="

    # Neovim config
    backup_and_link "$SDLC_ROOT/nvim" "$HOME/.config/nvim"

    # Tmux config
    backup_and_link "$SDLC_ROOT/tmux/tmux.conf" "$HOME/.tmux.conf"

    # Shell integration: append source lines to .bashrc if not already present
    local bashrc="$HOME/.bashrc"
    local env_line="source $SDLC_ROOT/shell/ai-env.sh"
    local alias_line="source $SDLC_ROOT/shell/ai-aliases.sh"

    if ! grep -qF "$env_line" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# AI SDLC toolkit" >> "$bashrc"
        echo "$env_line" >> "$bashrc"
        echo "$alias_line" >> "$bashrc"
        info "Added AI SDLC sources to $bashrc"
    else
        info "Shell sources already in $bashrc"
    fi

    # nono-claude wrapper on PATH
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    backup_and_link "$SDLC_ROOT/nono/scripts/nono-claude.sh" "$local_bin/nono-claude"
}

do_tools() {
    info "=== Installing tools ==="
    "$SDLC_ROOT/tools/install-tools.sh"
}

do_nvim_bootstrap() {
    info "=== Bootstrapping Neovim plugins ==="
    if command -v nvim &>/dev/null; then
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
        info "Neovim plugins synced"
    else
        warn "Neovim not found, skipping plugin bootstrap"
    fi
}

main() {
    local mode="${1:-all}"

    info "=== AI SDLC Toolkit Installer ==="
    info "Root: $SDLC_ROOT"
    echo

    case "$mode" in
        link|links)
            do_links
            ;;
        tools)
            do_tools
            ;;
        all)
            do_links
            do_tools
            do_nvim_bootstrap
            ;;
        *)
            echo "Usage: $0 [all|link|tools]"
            exit 1
            ;;
    esac

    echo
    info "=== Installation complete ==="
    echo
    echo "Next steps:"
    echo "  1. Restart your shell or run: source ~/.bashrc"
    echo "  2. Open neovim: nvim (plugins will auto-install on first launch)"
    echo "  3. Install caveman: ./tools/caveman/setup.sh"
    echo "  4. Try the AI workflow: tmux-ai ~/your/project"
}

main "$@"
