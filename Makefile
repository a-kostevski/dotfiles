# Dotfiles Makefile
# Common tasks for managing dotfiles

# Default shell
SHELL := /bin/bash

# Variables
BOOTSTRAP := ./bootstrap.sh
PROFILE ?= minimal
VERBOSE ?= false
ARGS ?=

# Colors
YELLOW := \033[1;33m
GREEN := \033[1;32m
RED := \033[1;31m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Phony targets
.PHONY: help install install-minimal install-standard install-full install-packages \
        apply-macos-defaults harden update uninstall test validate clean backup \
        docs deps version bootstrap-help

## Help
help:
	@echo "Dotfiles Management"
	@echo "=================="
	@echo ""
	@echo "Installation:"
	@echo "  make install          Install with default profile (minimal)"
	@echo "  make install-minimal  Install minimal profile"
	@echo "  make install-standard Install standard profile"  
	@echo "  make install-full     Install full profile"
	@echo "  make install-packages Install OS packages (explicit opt-in)"
	@echo "  make apply-macos-defaults Apply macOS system defaults"
	@echo "  make harden           Apply macOS security hardening"
	@echo ""
	@echo "Maintenance:"
	@echo "  make update          Update existing installation"
	@echo "  make uninstall       Remove dotfiles symlinks (restores backups)"
	@echo "  make validate        Check for broken symlinks"
	@echo "  make clean           Remove broken symlinks"
	@echo "  make backup          Backup current configs"
	@echo ""
	@echo "Development:"
	@echo "  make test            Run tests"
	@echo "  make deps            Check dependencies"
	@echo "  make docs            Generate documentation"
	@echo ""
	@echo "Options:"
	@echo "  PROFILE=<profile>    Set installation profile"
	@echo "  VERBOSE=true         Enable verbose output"
	@echo "  DRY_RUN=true         Run without making changes"
	@echo "  ARGS='...'           Extra args passed through to bootstrap/dotfiles"
	@echo ""
	@echo "Examples:"
	@echo "  make install PROFILE=standard VERBOSE=true"
	@echo "  make install-full DRY_RUN=true"

## Install with current profile
install:
	@echo -e "$(YELLOW)Installing dotfiles (profile: $(PROFILE))...$(NC)"
	@$(BOOTSTRAP) --profile $(PROFILE) $(if $(filter true,$(VERBOSE)),--verbose) $(if $(filter true,$(DRY_RUN)),--dry-run) $(ARGS)
	@echo -e "$(GREEN)Installation complete!$(NC)"

## Install minimal profile
install-minimal:
	@$(MAKE) install PROFILE=minimal

## Install standard profile
install-standard:
	@$(MAKE) install PROFILE=standard

## Install full profile
install-full:
	@$(MAKE) install PROFILE=full

## Install OS packages explicitly
install-packages:
	@$(BOOTSTRAP) --profile $(PROFILE) --install-packages $(if $(filter true,$(VERBOSE)),--verbose) $(if $(filter true,$(DRY_RUN)),--dry-run) $(ARGS)

## Apply macOS system defaults explicitly
apply-macos-defaults:
	@$(BOOTSTRAP) --apply-macos-defaults $(if $(filter true,$(DRY_RUN)),--dry-run) $(ARGS)

## Apply macOS security hardening explicitly
harden:
	@$(BOOTSTRAP) --harden $(if $(filter true,$(DRY_RUN)),--dry-run) $(ARGS)

## Update existing installation
update:
	@echo -e "$(YELLOW)Updating dotfiles...$(NC)"
	@if [ "$(DRY_RUN)" = "true" ]; then \
		echo "[DRY-RUN] git pull --ff-only"; \
	else \
		git pull --ff-only; \
	fi
	@bin/dotfiles sync $(if $(filter true,$(VERBOSE)),--verbose) $(if $(filter true,$(DRY_RUN)),--dry-run) $(ARGS)
	@echo -e "$(GREEN)Update complete!$(NC)"

## Uninstall dotfiles symlinks (restores backups; pass ARGS='nvim' to scope)
uninstall:
	@bin/dotfiles uninstall $(ARGS)

## Validate symlinks
validate:
	@bin/dotfiles status --summary

## Clean broken symlinks
clean:
	@bin/dotfiles clean $(ARGS)

## Backup current configurations
backup:
	@backup_dir="$$HOME/dotfiles-backup-$$(date +%Y%m%d-%H%M%S)"; \
	echo -e "$(YELLOW)Backing up to $$backup_dir...$(NC)"; \
	mkdir -p "$$backup_dir"; \
	for dir in .config .local/bin .zshenv .lldbinit; do \
		if [ -e "$$HOME/$$dir" ]; then \
			echo "Backing up $$dir..."; \
			cp -R "$$HOME/$$dir" "$$backup_dir/"; \
		fi \
	done; \
	echo -e "$(GREEN)Backup complete: $$backup_dir$(NC)"

## Run tests
# The Neovim smoke launcher is invoked explicitly by the dedicated CI job with
# a checksum-pinned NVIM_BIN. It is not a self-contained regression test.
TEST_SCRIPTS := $(filter-out tests/test-nvim-smoke.sh,$(wildcard tests/test-*.sh))

test:
	@echo -e "$(YELLOW)Running tests...$(NC)"
	@status=0; \
	for t in $(TEST_SCRIPTS); do \
		bash "$$t" || status=1; \
	done; \
	exit $$status

## Check dependencies
deps:
	@echo -e "$(YELLOW)Checking dependencies...$(NC)"
	@missing=0; \
	for cmd in git curl zsh tmux nvim; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo -e "$(GREEN)✓$(NC) $$cmd"; \
		else \
			echo -e "$(RED)✗$(NC) $$cmd"; \
			missing=$$((missing + 1)); \
		fi \
	done; \
	if [ $$missing -gt 0 ]; then \
		echo -e "$(RED)Missing $$missing dependencies$(NC)"; \
		exit 1; \
	else \
		echo -e "$(GREEN)All dependencies satisfied!$(NC)"; \
	fi

## Generate documentation
docs:
	@echo -e "$(YELLOW)Generating documentation...$(NC)"
	@if command -v tree >/dev/null 2>&1; then \
		echo "# Directory Structure" > docs/STRUCTURE.md; \
		echo '```' >> docs/STRUCTURE.md; \
		tree -a -I '.git|.DS_Store' >> docs/STRUCTURE.md; \
		echo '```' >> docs/STRUCTURE.md; \
		echo -e "$(GREEN)Documentation generated in docs/$(NC)"; \
	else \
		echo -e "$(RED)tree command not found$(NC)"; \
	fi

## Show version information
version:
	@echo "Dotfiles version information:"
	@echo "============================="
	@grep -E "SCRIPT_VERSION|SCRIPT_DATE" bootstrap.sh | sed 's/readonly //'
	@echo ""
	@echo "Git information:"
	@git describe --tags --always --dirty 2>/dev/null || echo "No git tags found"
	@echo "Latest commit: $$(git log -1 --format='%h - %s (%cr)' 2>/dev/null || echo 'Not a git repository')"

## Show bootstrap help
bootstrap-help:
	@$(BOOTSTRAP) --help

# Hidden targets for development

.check-executable:
	@for file in bootstrap.sh install/*.sh bin/*; do \
		if [ -f "$$file" ] && [ ! -x "$$file" ]; then \
			echo "Making executable: $$file"; \
			chmod +x "$$file"; \
		fi \
	done

.lint-shell:
	@if command -v shellcheck >/dev/null 2>&1; then \
		tests/lint-shell.sh; \
	else \
		echo "shellcheck not installed"; \
	fi

.stats:
	@echo "Repository Statistics"
	@echo "===================="
	@echo "Total files: $$(find . -type f -not -path './.git/*' | wc -l)"
	@echo "Config files: $$(find config -type f | wc -l)"
	@echo "Scripts: $$(find bin -type f 2>/dev/null | wc -l || echo 0)"
	@echo "Lines of code: $$(find . -type f -name '*.sh' -o -name '*.zsh' | xargs wc -l | tail -n1 | awk '{print $$1}')"
