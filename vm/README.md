# VM Provisioning

Provision a clean Fedora VM with the full AI SDLC toolkit pre-installed.
Uses libvirt/KVM with cloud-init for automated setup.

## Prerequisites

- Linux host with libvirt, QEMU/KVM, and `virt-install`
- SSH public key in `~/.ssh/`
- At least 4GB RAM and 20GB disk available for the VM

```bash
# Fedora: install libvirt stack
sudo dnf install -y @virtualization
sudo systemctl enable --now libvirtd
```

## Usage

### Create a VM

```bash
./create-vm.sh [vm-name] [vm-ip]
```

Defaults to `sdlc-dev` and `192.168.122.50`.

```bash
# Default
./create-vm.sh

# Custom name and IP
./create-vm.sh my-dev-box 192.168.122.100
```

The script will:
1. Download a Fedora cloud image (if not cached)
2. Create a cloud-init ISO with your SSH key and the provisioning script
3. Launch a VM with 4 vCPUs, 4GB RAM, 40GB disk
4. Install all tools (neovim, claude-code, nono, speckit, diffity, etc.)
5. Deploy the sdlc neovim/tmux/shell configuration

### Connect

```bash
ssh dev@192.168.122.50
```

Or with the custom IP you specified.

### Use

Once inside the VM:

```bash
# Start an AI-assisted coding session
tmux-ai ~/workspace

# Or clone a project and work on it
git clone git@github.com:org/repo.git ~/workspace/repo
tmux-ai ~/workspace/repo
```

### Tear Down

```bash
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

### cloud-init User Data

Edit `user-data.yaml` to customize:
- Packages installed in the VM
- User account name (default: `dev`)
- Additional SSH keys
- Custom shell configuration

### Provisioning Script

Edit `provision.sh` to customize:
- Which tools are installed
- Additional language runtimes
- Project-specific setup

### VM Resources

Edit `create-vm.sh` to change:
- `VM_CPUS` (default: 4)
- `VM_RAM` (default: 4096 MB)
- `VM_DISK` (default: 40 GB)
