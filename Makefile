SDLC_ROOT := $(shell pwd)

VM_NAME ?= sdlc-dev
export LIBVIRT_DEFAULT_URI := qemu:///system

.PHONY: install link tools nvim-sync caveman clean help
.PHONY: vm vm-destroy vm-ssh vm-status vm-inject

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# --- Local install ---

install: ## Full install: symlinks + tools + neovim plugins
	@./install.sh all

link: ## Create symlinks only (no tool install)
	@./install.sh link

tools: ## Install external tools only
	@./install.sh tools

nvim-sync: ## Sync neovim plugins via lazy.nvim
	nvim --headless "+Lazy! sync" +qa

caveman: ## Install caveman plugin for Claude Code
	@./tools/caveman/setup.sh

clean: ## Remove symlinks (does not uninstall tools)
	@echo "Removing symlinks..."
	@rm -f $(HOME)/.config/nvim 2>/dev/null || true
	@rm -f $(HOME)/.tmux.conf 2>/dev/null || true
	@rm -f $(HOME)/.local/bin/nono-claude 2>/dev/null || true
	@echo "Done. Shell sources in .bashrc must be removed manually."

# --- VM management ---

vm: ## Create a provisioned VM (VM_NAME=x)
	@./vm/create-vm.sh $(VM_NAME)

vm-destroy: ## Destroy the VM and clean up disks
	@./vm/teardown-vm.sh $(VM_NAME)

vm-ssh: ## SSH into the VM (auto-discovers IP)
	@MAC=$$(virsh domiflist $(VM_NAME) 2>/dev/null | awk '/virtio/{print $$5}'); \
	IP=$$(virsh net-dhcp-leases default 2>/dev/null | grep "$$MAC" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1); \
	if [ -z "$$IP" ]; then echo "No IP found. Is the VM running?"; exit 1; fi; \
	echo "Connecting to dev@$$IP..."; \
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dev@$$IP

vm-status: ## Show VM status and IP
	@virsh dominfo $(VM_NAME) 2>/dev/null || echo "VM '$(VM_NAME)' does not exist."
	@echo "---"
	@virsh net-dhcp-leases default 2>/dev/null || true

vm-console: ## Attach to VM serial console
	@virsh console $(VM_NAME)

vm-inject: ## Re-inject host configs (claude, git, gh) into running VM
	@MAC=$$(virsh domiflist $(VM_NAME) 2>/dev/null | awk '/virtio/{print $$5}'); \
	IP=$$(virsh net-dhcp-leases default 2>/dev/null | grep "$$MAC" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1); \
	if [ -z "$$IP" ]; then echo "No IP found. Is the VM running?"; exit 1; fi; \
	SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"; \
	echo "Injecting host configs into dev@$$IP..."; \
	[ -f "$$HOME/.claude.json" ] && scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$$HOME/.claude.json" dev@$$IP:~/.claude.json 2>/dev/null && echo "  -> claude.json"; \
	[ -d "$$HOME/.claude" ] && rsync -az --exclude='session-env' --exclude='debug' --exclude='shell-snapshots' -e "$$SSH" "$$HOME/.claude/" dev@$$IP:~/.claude/ 2>/dev/null && echo "  -> .claude/"; \
	[ -f "$$HOME/.gitconfig" ] && scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$$HOME/.gitconfig" dev@$$IP:~/.gitconfig 2>/dev/null && echo "  -> gitconfig"; \
	if [ -f "$$HOME/.config/gh/hosts.yml" ]; then $$SSH dev@$$IP "mkdir -p ~/.config/gh" 2>/dev/null; scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$$HOME/.config/gh/hosts.yml" dev@$$IP:~/.config/gh/hosts.yml 2>/dev/null && echo "  -> gh auth"; fi; \
	echo "Done."

vm-rebuild: vm-destroy vm ## Destroy and recreate the VM
