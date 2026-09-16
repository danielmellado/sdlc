#!/usr/bin/env bash
# Install NVIDIA OpenShell CLI and verify driver availability.
# Supports Podman and MicroVM (libkrun/KVM) drivers.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

install_openshell_cli() {
    if command -v openshell &>/dev/null; then
        info "openshell already installed: $(openshell --version 2>/dev/null || echo 'installed')"
        return
    fi

    info "Installing OpenShell CLI..."
    curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh
}

check_drivers() {
    echo ""
    info "=== Checking available drivers ==="

    if command -v podman &>/dev/null; then
        local podman_ver
        podman_ver="$(podman --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)"
        info "Podman detected: v${podman_ver}"
        if [[ "${podman_ver%%.*}" -ge 5 ]]; then
            info "  Podman 5.x OK -- use: openshell-ai --podman"
        else
            warn "  Podman < 5.x -- OpenShell requires Podman 5.x+"
        fi
    else
        warn "Podman not found. Install podman for container-based sandboxes."
    fi

    if [[ -c /dev/kvm ]]; then
        info "KVM detected: /dev/kvm available"
        info "  MicroVM driver OK -- use: openshell-ai --microvm"
    else
        warn "KVM not available. MicroVM driver requires hardware virtualization."
    fi

    echo ""
}

main() {
    info "=== OpenShell Installer ==="
    echo ""
    install_openshell_cli
    check_drivers
    info "=== Done ==="
    echo ""
    echo "Usage:"
    echo "  openshell-ai ~/project                    # Claude Code (auto-detect driver)"
    echo "  openshell-ai ~/project --opencode         # OpenCode"
    echo "  openshell-ai ~/project --podman           # Force Podman driver"
    echo "  openshell-ai ~/project --microvm          # Force MicroVM driver"
    echo ""
    echo "Policies are in openshell/policy-{claude,opencode}.yaml"
}

main "$@"
