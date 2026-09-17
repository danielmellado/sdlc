SDLC_ROOT := $(shell pwd)

VM_NAME ?= sdlc-dev
export LIBVIRT_DEFAULT_URI := qemu:///system

.PHONY: install link tools nvim-sync caveman clean help
.PHONY: vm vm-destroy vm-ssh vm-status vm-inject vm-stop vm-suspend

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

openshell: ## Install OpenShell (optional sandbox: Podman or MicroVM)
	@./openshell/install-openshell.sh

clean: ## Remove symlinks (does not uninstall tools)
	@echo "Removing symlinks..."
	@rm -f $(HOME)/.config/nvim 2>/dev/null || true
	@rm -f $(HOME)/.tmux.conf 2>/dev/null || true
	@rm -f $(HOME)/.local/bin/nono-claude 2>/dev/null || true
	@rm -f $(HOME)/.local/bin/nono-opencode 2>/dev/null || true
	@echo "Done. Shell sources in .bashrc must be removed manually."

# --- VM management ---

vm: ## Create a provisioned VM (VM_NAME=x)
	@./vm/create-vm.sh $(VM_NAME)

vm-destroy: ## Destroy the VM and clean up disks
	@./vm/teardown-vm.sh $(VM_NAME)

vm-ssh: ## SSH into the VM (auto-starts if stopped, auto-discovers IP)
	@STATE=$$(virsh domstate $(VM_NAME) 2>/dev/null); \
	if [ -z "$$STATE" ]; then echo "VM '$(VM_NAME)' does not exist. Create it with: make vm"; exit 1; fi; \
	COLD_START=false; \
	if [ "$$STATE" = "paused" ]; then \
		echo "VM is suspended, resuming..."; \
		virsh resume $(VM_NAME); \
	elif [ "$$STATE" != "running" ]; then \
		echo "VM is $$STATE, starting..."; \
		virsh start $(VM_NAME); \
		echo "Waiting for DHCP lease..."; \
		sleep 10; \
		COLD_START=true; \
	fi; \
	MAC=$$(virsh domiflist $(VM_NAME) 2>/dev/null | awk '/virtio/{print $$5}'); \
	IP=""; \
	for i in $$(seq 1 12); do \
		IP=$$(virsh net-dhcp-leases default 2>/dev/null | grep "$$MAC" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1); \
		[ -n "$$IP" ] && break; \
		sleep 5; \
	done; \
	if [ -z "$$IP" ]; then echo "No IP found after 60s. Check: virsh net-dhcp-leases default"; exit 1; fi; \
	if [ "$$COLD_START" = "true" ]; then \
		echo "Re-injecting host configs after cold start..."; \
		$(MAKE) vm-inject 2>/dev/null || echo "(inject skipped — VM may still be booting)"; \
	fi; \
	echo "Connecting to dev@$$IP (diffity on http://localhost:5391 when running)..."; \
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -L 5391:localhost:5391 dev@$$IP

vm-status: ## Show VM status and IP
	@virsh dominfo $(VM_NAME) 2>/dev/null || echo "VM '$(VM_NAME)' does not exist."
	@echo "---"
	@virsh net-dhcp-leases default 2>/dev/null || true

vm-console: ## Attach to VM serial console
	@virsh console $(VM_NAME)

vm-inject: ## Re-inject host configs (claude, git, gh, gcloud) into running VM
	@MAC=$$(virsh domiflist $(VM_NAME) 2>/dev/null | awk '/virtio/{print $$5}'); \
	IP=$$(virsh net-dhcp-leases default 2>/dev/null | grep "$$MAC" | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1); \
	if [ -z "$$IP" ]; then echo "No IP found. Is the VM running?"; exit 1; fi; \
	SSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"; \
	SCP="scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"; \
	echo "Injecting host configs into dev@$$IP..."; \
	[ -f "$$HOME/.claude.json" ] && $$SCP "$$HOME/.claude.json" dev@$$IP:~/.claude.json 2>/dev/null && echo "  -> claude.json"; \
	[ -d "$$HOME/.claude" ] && rsync -az --exclude='session-env' --exclude='debug' --exclude='shell-snapshots' -e "$$SSH" "$$HOME/.claude/" dev@$$IP:~/.claude/ 2>/dev/null && echo "  -> .claude/"; \
	[ -f "$$HOME/.gitconfig" ] && $$SCP "$$HOME/.gitconfig" dev@$$IP:~/.gitconfig 2>/dev/null && echo "  -> gitconfig"; \
	if [ -f "$$HOME/.config/gh/hosts.yml" ]; then $$SSH dev@$$IP "mkdir -p ~/.config/gh" 2>/dev/null; $$SCP "$$HOME/.config/gh/hosts.yml" dev@$$IP:~/.config/gh/hosts.yml 2>/dev/null && echo "  -> gh auth"; fi; \
	if [ -d "$$HOME/.config/gcloud" ]; then $$SSH dev@$$IP "mkdir -p ~/.config/gcloud" 2>/dev/null; \
		rsync -az -e "$$SSH" --include='credentials.db' --include='access_tokens.db' --include='application_default_credentials.json' --include='active_config' --include='configurations/***' --include='default_configs.db' --exclude='*' \
			"$$HOME/.config/gcloud/" dev@$$IP:~/.config/gcloud/ 2>/dev/null && echo "  -> gcloud credentials"; fi; \
	VERTEX_VARS=""; \
	[ -n "$$CLAUDE_CODE_USE_VERTEX" ] && VERTEX_VARS="$$VERTEX_VARS\nexport CLAUDE_CODE_USE_VERTEX=$$CLAUDE_CODE_USE_VERTEX"; \
	[ -n "$$CLOUD_ML_REGION" ] && VERTEX_VARS="$$VERTEX_VARS\nexport CLOUD_ML_REGION=$$CLOUD_ML_REGION"; \
	[ -n "$$ANTHROPIC_VERTEX_PROJECT_ID" ] && VERTEX_VARS="$$VERTEX_VARS\nexport ANTHROPIC_VERTEX_PROJECT_ID=$$ANTHROPIC_VERTEX_PROJECT_ID"; \
	if [ -n "$$VERTEX_VARS" ]; then \
		$$SSH dev@$$IP "grep -q CLAUDE_CODE_USE_VERTEX ~/.bashrc 2>/dev/null || printf '$$VERTEX_VARS\n' >> ~/.bashrc" 2>/dev/null && echo "  -> vertex env vars"; \
	fi; \
	if [ -d "$$HOME/.local/share/opencode" ]; then $$SSH dev@$$IP "mkdir -p ~/.local/share/opencode" 2>/dev/null; \
		rsync -az -e "$$SSH" "$$HOME/.local/share/opencode/" dev@$$IP:~/.local/share/opencode/ 2>/dev/null && echo "  -> opencode auth"; fi; \
	if [ -d "$$HOME/.config/opencode" ]; then $$SSH dev@$$IP "mkdir -p ~/.config/opencode" 2>/dev/null; \
		rsync -az -e "$$SSH" "$$HOME/.config/opencode/" dev@$$IP:~/.config/opencode/ 2>/dev/null && echo "  -> opencode config"; fi; \
	echo "Done."

vm-stop: ## Gracefully shut down the VM
	@STATE=$$(virsh domstate $(VM_NAME) 2>/dev/null); \
	if [ "$$STATE" = "running" ]; then \
		echo "Shutting down $(VM_NAME)..."; \
		virsh shutdown $(VM_NAME); \
		echo "Waiting for shutdown..."; \
		for i in $$(seq 1 30); do \
			STATE=$$(virsh domstate $(VM_NAME) 2>/dev/null); \
			[ "$$STATE" = "shut off" ] && break; \
			sleep 2; \
		done; \
		STATE=$$(virsh domstate $(VM_NAME) 2>/dev/null); \
		if [ "$$STATE" != "shut off" ]; then \
			echo "VM did not shut down cleanly after 60s, forcing off..."; \
			virsh destroy $(VM_NAME); \
		fi; \
		echo "$(VM_NAME) stopped."; \
	else \
		echo "VM is already $$STATE."; \
	fi

vm-suspend: ## Suspend VM (preserves RAM state, fast resume)
	@STATE=$$(virsh domstate $(VM_NAME) 2>/dev/null); \
	if [ "$$STATE" = "running" ]; then \
		echo "Suspending $(VM_NAME)..."; \
		virsh suspend $(VM_NAME); \
		echo "$(VM_NAME) suspended. Resume with: make vm-ssh"; \
	elif [ "$$STATE" = "paused" ]; then \
		echo "$(VM_NAME) is already suspended. Resuming..."; \
		virsh resume $(VM_NAME); \
		echo "$(VM_NAME) resumed."; \
	else \
		echo "VM is $$STATE, cannot suspend."; \
	fi

vm-rebuild: vm-destroy vm ## Destroy and recreate the VM
