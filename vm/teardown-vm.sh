#!/usr/bin/env bash
# Tear down a VM created by create-vm.sh.
#
# Usage: ./teardown-vm.sh [vm-name]
set -euo pipefail

export LIBVIRT_DEFAULT_URI="qemu:///system"

VM_NAME="${1:-sdlc-dev}"
CACHE_DIR="/var/lib/libvirt/images/sdlc-vm"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

if ! virsh dominfo "$VM_NAME" &>/dev/null; then
    warn "VM '$VM_NAME' does not exist."
    exit 0
fi

info "Stopping VM '$VM_NAME'..."
virsh destroy "$VM_NAME" 2>/dev/null || true

info "Removing VM definition..."
virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true

# Clean up cloud-init ISO and disk
for f in "${CACHE_DIR}/${VM_NAME}.qcow2" "${CACHE_DIR}/${VM_NAME}-cidata.iso"; do
    if [[ -f "$f" ]]; then
        rm -f "$f"
        info "Removed: $f"
    fi
done

info "VM '$VM_NAME' has been torn down."
info "Base image preserved at: ${CACHE_DIR}/fedora-cloud-*.qcow2"
