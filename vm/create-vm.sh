#!/usr/bin/env bash
# Provision a Fedora VM with the full AI SDLC toolkit.
#
# Usage:
#   ./create-vm.sh [vm-name]
#
# Prerequisites: libvirt, qemu-kvm, virt-install, genisoimage/mkisofs
set -euo pipefail

export LIBVIRT_DEFAULT_URI="qemu:///system"

VM_NAME="${1:-sdlc-dev}"
VM_CPUS=4
VM_RAM=8192
VM_DISK=40

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(dirname "$SCRIPT_DIR")"
LIBVIRT_IMAGES="/var/lib/libvirt/images"
CACHE_DIR="${LIBVIRT_IMAGES}/sdlc-vm"
FEDORA_VERSION="44"
FEDORA_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-${FEDORA_VERSION}-1.7.x86_64.qcow2"
FEDORA_IMAGE="${CACHE_DIR}/fedora-cloud-${FEDORA_VERSION}.qcow2"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*" >&2; }

# --- Preflight checks ---
for cmd in virsh virt-install qemu-img genisoimage; do
    if ! command -v "$cmd" &>/dev/null; then
        if [[ "$cmd" == "genisoimage" ]] && command -v mkisofs &>/dev/null; then
            continue
        fi
        err "Required command not found: $cmd"
        err "Install with: sudo dnf install -y @virtualization genisoimage"
        exit 1
    fi
done

# Ensure libvirt modular daemons are running and enabled on boot
for svc in virtqemud virtnetworkd virtstoraged; do
    if ! systemctl is-active --quiet "$svc.socket" 2>/dev/null; then
        info "Starting ${svc}..."
        sudo systemctl start "${svc}.socket" "${svc}.service"
    fi
    sudo systemctl enable --quiet "${svc}.socket" 2>/dev/null || true
done

# Ensure the default network is active and set to autostart
if ! virsh net-info default 2>/dev/null | grep -q "Active:.*yes"; then
    info "Starting libvirt default network..."
    virsh net-start default 2>/dev/null || true
fi
virsh net-autostart default 2>/dev/null || true

if virsh dominfo "$VM_NAME" &>/dev/null; then
    err "VM '$VM_NAME' already exists. Tear it down first:"
    err "  ./teardown-vm.sh $VM_NAME"
    exit 1
fi

# --- Download Fedora cloud image ---
sudo mkdir -p "$CACHE_DIR"
if [[ ! -f "$FEDORA_IMAGE" ]]; then
    info "Downloading Fedora ${FEDORA_VERSION} cloud image..."
    sudo curl -L -o "$FEDORA_IMAGE" "$FEDORA_IMAGE_URL"
else
    info "Using cached Fedora image: $FEDORA_IMAGE"
fi

# --- Create VM disk ---
VM_DISK_PATH="${CACHE_DIR}/${VM_NAME}.qcow2"
info "Creating VM disk (${VM_DISK}GB) from base image..."
sudo qemu-img create -f qcow2 -b "$FEDORA_IMAGE" -F qcow2 "$VM_DISK_PATH" "${VM_DISK}G"

# --- Find SSH public key ---
SSH_PUB_KEY=""
for key in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
    if [[ -f "$key" ]]; then
        SSH_PUB_KEY="$(cat "$key")"
        break
    fi
done

if [[ -z "$SSH_PUB_KEY" ]]; then
    err "No SSH public key found in ~/.ssh/"
    exit 1
fi

# --- Generate cloud-init ISO ---
CLOUD_INIT_DIR="$(mktemp -d)"
trap 'rm -rf "$CLOUD_INIT_DIR"' EXIT

cat > "${CLOUD_INIT_DIR}/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

PROVISION_SCRIPT="$(cat "$SCRIPT_DIR/provision.sh")"

cat > "${CLOUD_INIT_DIR}/user-data" <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}.local

users:
  - name: dev
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: wheel
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}

package_update: true
packages:
  - git
  - tmux
  - neovim
  - nodejs
  - npm
  - golang
  - rust
  - cargo
  - python3
  - python3-pip
  - gcc
  - gcc-c++
  - make
  - cmake
  - unzip
  - ripgrep
  - fd-find
  - jq
  - gh
  - podman
  - buildah
  - skopeo
  - ShellCheck
  - qemu-guest-agent

write_files:
  - path: /opt/sdlc-provision.sh
    permissions: '0755'
    content: |
$(echo "$PROVISION_SCRIPT" | sed 's/^/      /')

runcmd:
  - systemctl enable --now qemu-guest-agent
  - mkdir -p /etc/systemd/system/user-1000.slice.d && printf '[Slice]\nMemoryMax=infinity\n' > /etc/systemd/system/user-1000.slice.d/override.conf && systemctl daemon-reload
  - su - dev -c '/opt/sdlc-provision.sh'
EOF

CLOUD_INIT_ISO="${CACHE_DIR}/${VM_NAME}-cidata.iso"
CLOUD_INIT_ISO_TMP="${CLOUD_INIT_DIR}/cidata.iso"
if command -v genisoimage &>/dev/null; then
    genisoimage -output "$CLOUD_INIT_ISO_TMP" -volid cidata -joliet -rock \
        "${CLOUD_INIT_DIR}/meta-data" \
        "${CLOUD_INIT_DIR}/user-data"
else
    mkisofs -output "$CLOUD_INIT_ISO_TMP" -volid cidata -joliet -rock \
        "${CLOUD_INIT_DIR}/meta-data" \
        "${CLOUD_INIT_DIR}/user-data"
fi
sudo mv "$CLOUD_INIT_ISO_TMP" "$CLOUD_INIT_ISO"

# --- Launch VM (DHCP from libvirt default network) ---
info "Creating VM: ${VM_NAME} (${VM_CPUS} vCPUs, ${VM_RAM}MB RAM, ${VM_DISK}GB disk)"

virt-install \
    --name "$VM_NAME" \
    --memory "$VM_RAM" \
    --vcpus "$VM_CPUS" \
    --disk path="$VM_DISK_PATH",format=qcow2 \
    --disk path="$CLOUD_INIT_ISO",device=cdrom \
    --os-variant fedora-unknown \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    --autostart \
    --import

# --- Ensure iptables FORWARD allows VM traffic ---
# Docker sets the FORWARD chain policy to DROP, which blocks libvirt NAT.
if sudo iptables -L FORWARD -n 2>/dev/null | head -1 | grep -q "DROP"; then
    info "Docker FORWARD DROP detected, adding virbr0 rules..."
    sudo iptables -I FORWARD 1 -d 192.168.122.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -I FORWARD 2 -s 192.168.122.0/24 -j ACCEPT
    sudo iptables -I FORWARD 3 -i virbr0 -o virbr0 -j ACCEPT
fi

# --- Wait for IP ---
info "VM booting, waiting for DHCP lease..."
VM_MAC=$(virsh domiflist "$VM_NAME" 2>/dev/null | awk '/virtio/{print $5}') || true
VM_IP=""
for i in $(seq 1 60); do
    if [[ -n "$VM_MAC" ]]; then
        VM_IP=$(virsh net-dhcp-leases default 2>/dev/null \
            | grep "$VM_MAC" \
            | grep -oP '\d+\.\d+\.\d+\.\d+' \
            | head -1) || true
    fi
    if [[ -n "$VM_IP" ]]; then
        break
    fi
    sleep 5
done

if [[ -z "$VM_IP" ]]; then
    warn "Could not detect VM IP after 5 minutes."
    warn "Check manually: virsh net-dhcp-leases default"
    warn "Or:             virsh domifaddr $VM_NAME --source agent"
    info ""
    info "Tear down with:"
    info "  ./teardown-vm.sh $VM_NAME"
    exit 0
fi

info "VM IP: ${VM_IP}"

# --- Wait for SSH to become available ---
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
info "Waiting for SSH..."
for i in $(seq 1 30); do
    if ssh $SSH_OPTS dev@"$VM_IP" true 2>/dev/null; then
        break
    fi
    sleep 5
done

# --- Inject host configs into the VM ---
info "Injecting host configs into VM..."

# Claude Code auth + settings
if [[ -f "$HOME/.claude.json" ]]; then
    info "  -> Claude Code config (~/.claude.json)"
    scp $SSH_OPTS "$HOME/.claude.json" dev@"$VM_IP":~/.claude.json 2>/dev/null
fi
if [[ -d "$HOME/.claude" ]]; then
    info "  -> Claude Code data (~/.claude/)"
    rsync -az --exclude='session-env' --exclude='debug' --exclude='shell-snapshots' \
        -e "ssh $SSH_OPTS" "$HOME/.claude/" dev@"$VM_IP":~/.claude/ 2>/dev/null
fi

# Git identity
if [[ -f "$HOME/.gitconfig" ]]; then
    info "  -> Git config (~/.gitconfig)"
    scp $SSH_OPTS "$HOME/.gitconfig" dev@"$VM_IP":~/.gitconfig 2>/dev/null
fi

# GitHub CLI auth
if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
    info "  -> GitHub CLI auth (~/.config/gh/)"
    ssh $SSH_OPTS dev@"$VM_IP" "mkdir -p ~/.config/gh" 2>/dev/null
    scp $SSH_OPTS "$HOME/.config/gh/hosts.yml" dev@"$VM_IP":~/.config/gh/hosts.yml 2>/dev/null
fi

# Google Cloud / Vertex AI credentials (needed for Claude Code via Vertex)
if [[ -d "$HOME/.config/gcloud" ]]; then
    info "  -> gcloud credentials (~/.config/gcloud/)"
    ssh $SSH_OPTS dev@"$VM_IP" "mkdir -p ~/.config/gcloud" 2>/dev/null
    rsync -az -e "ssh $SSH_OPTS" \
        --include='credentials.db' --include='access_tokens.db' \
        --include='application_default_credentials.json' \
        --include='active_config' --include='configurations/***' \
        --include='default_configs.db' --exclude='*' \
        "$HOME/.config/gcloud/" dev@"$VM_IP":~/.config/gcloud/ 2>/dev/null
fi

# Vertex AI environment variables
VERTEX_VARS=""
[[ -n "${CLAUDE_CODE_USE_VERTEX:-}" ]] && VERTEX_VARS+="export CLAUDE_CODE_USE_VERTEX=${CLAUDE_CODE_USE_VERTEX}\n"
[[ -n "${CLOUD_ML_REGION:-}" ]] && VERTEX_VARS+="export CLOUD_ML_REGION=${CLOUD_ML_REGION}\n"
[[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]] && VERTEX_VARS+="export ANTHROPIC_VERTEX_PROJECT_ID=${ANTHROPIC_VERTEX_PROJECT_ID}\n"
if [[ -n "$VERTEX_VARS" ]]; then
    info "  -> Vertex AI env vars"
    ssh $SSH_OPTS dev@"$VM_IP" "grep -q CLAUDE_CODE_USE_VERTEX ~/.bashrc 2>/dev/null || printf '${VERTEX_VARS}' >> ~/.bashrc" 2>/dev/null
fi

# --- Ensure essential packages are installed (cloud-init package phase may have failed) ---
info "Ensuring essential packages are installed..."
ssh $SSH_OPTS dev@"$VM_IP" "sudo dnf install -y --nogpgcheck git tmux neovim nodejs npm golang rust cargo \
    python3 python3-pip gcc gcc-c++ make cmake unzip ripgrep fd-find jq gh podman ShellCheck" || \
    warn "Package install may have failed. Check connectivity inside the VM."

# --- Ensure sdlc repo is cloned and shell integration is set up ---
if ! ssh $SSH_OPTS dev@"$VM_IP" "test -d ~/sdlc/.git" 2>/dev/null; then
    info "Cloning sdlc repo into VM..."
    ssh $SSH_OPTS dev@"$VM_IP" "rm -rf ~/sdlc; git clone https://github.com/danielmellado/sdlc.git ~/sdlc" 2>/dev/null || \
        warn "Could not clone sdlc repo. Clone manually: git clone https://github.com/danielmellado/sdlc.git ~/sdlc"
fi

# --- Install nono + Claude Code CLI ---
info "Installing nono and Claude Code CLI..."
ssh $SSH_OPTS dev@"$VM_IP" bash -s 2>/dev/null <<'TOOLSEOF'
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local"

# uv (Python package manager, needed for speckit)
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh || echo "[!] uv install failed"
    export PATH="$HOME/.local/bin:$PATH"
fi

# nono (kernel sandbox)
if ! command -v nono &>/dev/null; then
    curl -fsSL https://nono.sh/install.sh | sh || echo "[!] nono install failed"
fi
NONO_AUTO_MIGRATE=1 nono pull always-further/claude 2>/dev/null || true

# Claude Code CLI
if ! command -v claude &>/dev/null; then
    npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local" || echo "[!] claude install failed"
fi

# diffity (diff review)
if ! command -v diffity &>/dev/null; then
    npm install -g diffity --prefix "$HOME/.local" || echo "[!] diffity install failed"
fi

# speckit (spec-driven development)
if ! command -v specify &>/dev/null; then
    uv tool install specify-cli --from "git+https://github.com/github/spec-kit.git" || echo "[!] speckit install failed"
fi

# caveman (Claude Code plugin for token reduction)
if command -v claude &>/dev/null; then
    claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null || true
    claude plugin install caveman@caveman 2>/dev/null || echo "[!] caveman install failed"
fi
TOOLSEOF

# Deploy sdlc shell integration and symlinks
info "Deploying sdlc config..."
ssh $SSH_OPTS dev@"$VM_IP" bash -s 2>/dev/null <<'REMOTEOF'
if [[ -d ~/sdlc ]]; then
    mkdir -p ~/.config ~/.local/bin
    ln -sfn ~/sdlc/nvim ~/.config/nvim
    ln -sf ~/sdlc/tmux/tmux.conf ~/.tmux.conf
    ln -sf ~/sdlc/nono/scripts/nono-claude.sh ~/.local/bin/nono-claude
    if ! grep -qF "sdlc/shell/ai-env.sh" ~/.bashrc 2>/dev/null; then
        printf '\n# AI SDLC toolkit\nsource ~/sdlc/shell/ai-env.sh\nsource ~/sdlc/shell/ai-aliases.sh\n' >> ~/.bashrc
    fi
    if [[ ! -f ~/.bash_profile ]] || ! grep -qF ".bashrc" ~/.bash_profile 2>/dev/null; then
        printf '[[ -f ~/.bashrc ]] && source ~/.bashrc\n' >> ~/.bash_profile
    fi
fi
REMOTEOF

info ""
info "VM ready! Connect with:"
info "  make vm-ssh"
info ""
info "Tear down with:"
info "  ./teardown-vm.sh $VM_NAME"
