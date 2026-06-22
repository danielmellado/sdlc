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
VM_RAM=4096
VM_DISK=40

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(dirname "$SCRIPT_DIR")"
LIBVIRT_IMAGES="/var/lib/libvirt/images"
CACHE_DIR="${LIBVIRT_IMAGES}/sdlc-vm"
FEDORA_VERSION="42"
FEDORA_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA_VERSION}/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-${FEDORA_VERSION}-1.1.x86_64.qcow2"
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

info ""
info "Cloud-init provisioning will take a few more minutes."
info ""
info "Monitor progress:"
info "  virsh console $VM_NAME"
info ""
info "Once ready, connect with:"
info "  ssh dev@${VM_IP}"
info ""
info "Tear down with:"
info "  ./teardown-vm.sh $VM_NAME"
