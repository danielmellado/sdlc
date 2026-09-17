# VM Provisioning

Provision a clean Fedora VM with the full AI SDLC toolkit pre-installed.
Uses libvirt/KVM with cloud-init for automated setup.

## Prerequisites

- Linux host with libvirt, QEMU/KVM, and `virt-install`
- SSH public key in `~/.ssh/`
- At least 8GB RAM and 40GB disk available for the VM

```bash
# Fedora: install libvirt stack
sudo dnf install -y @virtualization genisoimage
sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket
```

## Usage

### Create a VM

```bash
./create-vm.sh [vm-name]
```

Defaults to `sdlc-dev`. The VM gets an IP via DHCP from the libvirt
`default` network.

```bash
# Default
./create-vm.sh

# Custom name
./create-vm.sh my-dev-box
```

The script will:
1. Download a Fedora 44 cloud image (if not cached)
2. Create a cloud-init ISO with your SSH key and the provisioning script
3. Launch a VM with 4 vCPUs, 8GB RAM, 40GB disk
4. Wait for DHCP lease and SSH availability
5. Inject host configs (Claude, git, gh, gcloud auth)
6. Install all tools (neovim, claude-code, nono, opencode, speckit, diffity, etc.)
7. Deploy the sdlc neovim/tmux/shell configuration

### Connect

```bash
make vm-ssh
```

This auto-starts the VM if it's stopped, discovers the IP via DHCP, and
SSH-es in with port forwarding for diffity (localhost:5391).

You can also connect manually once you know the IP:

```bash
virsh net-dhcp-leases default    # find the IP
ssh dev@<vm-ip>
```

### Use

Once inside the VM:

```bash
# Start an AI-assisted coding session
tmux-ai ~/workspace

# Or clone a project and work on it
git clone git@github.com:org/repo.git ~/workspace/repo
tmux-ai ~/workspace/repo
```

### Manage

```bash
make vm-status    # Show VM state and DHCP leases
make vm-ssh       # SSH in (auto-starts if stopped)
make vm-inject    # Re-inject host configs (claude, git, gh, gcloud)
make vm-stop      # Gracefully shut down the VM
make vm-suspend   # Suspend VM (preserves RAM state)
make vm-console   # Attach to serial console
make vm-rebuild   # Destroy and recreate from scratch
```

### Tear Down

```bash
make vm-destroy
# or
./teardown-vm.sh [vm-name]
```

### Accessing Services from Your Laptop

If the VM runs on a remote server, use SSH port forwarding to access
diffity or other browser-based tools:

```bash
# Forward diffity from VM through the server to your laptop
ssh -L 5391:<vm-ip>:5391 user@server-ip
# Then open http://localhost:5391
```

## Customization

### VM Resources

Edit `create-vm.sh` to change:
- `VM_CPUS` (default: 4)
- `VM_RAM` (default: 8192 MB)
- `VM_DISK` (default: 40 GB)

### Cloud-init

The cloud-init user-data is generated inline in `create-vm.sh`. Edit the
heredoc to customize:
- Packages installed in the VM
- User account name (default: `dev`)
- Additional SSH keys

### Provisioning Script

Edit `provision.sh` to customize:
- Which tools are installed
- Additional language runtimes
- Project-specific setup
