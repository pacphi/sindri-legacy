.PHONY: help install clean
.PHONY: deps-check deps-check-minor deps-check-patch deps-upgrade deps-upgrade-minor deps-upgrade-patch deps-upgrade-interactive
.PHONY: audit audit-fix audit-fix-force security
.PHONY: format format-check format-md lint lint-fix lint-shell lint-md validate
.PHONY: test test-extensions test-workflows
.PHONY: vm-deploy vm-status vm-suspend vm-resume vm-teardown vm-logs
.PHONY: cost-monitor backup restore
.PHONY: docs bom-report
.PHONY: ssh ssh-fly extensions-list
.PHONY: dev-setup quick-start
.PHONY: check-scripts

# Default app name for VM operations (override with: make vm-deploy APP_NAME=myapp)
APP_NAME ?= sindri-dev
REGION ?= sjc
FLY_TOKEN ?= $(FLYIO_AUTH_TOKEN)

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

check-scripts: ## Validate that required scripts exist
	@echo "Checking required scripts..."
	@for script in \
		scripts/vm-setup.sh \
		scripts/vm-suspend.sh \
		scripts/vm-resume.sh \
		scripts/vm-teardown.sh \
		scripts/cost-monitor.sh \
		scripts/volume-backup.sh \
		scripts/volume-restore.sh \
		scripts/generate-bom-report.sh; do \
		if [ ! -f "$$script" ]; then \
			echo "✗ Missing required script: $$script"; \
			exit 1; \
		fi; \
	done
	@echo "✓ All required scripts found"

install: ## Install Node.js dependencies (requires Node.js >= 22, pnpm >= 9)
	@echo "Installing Node.js dependencies..."
	@pnpm install
	@echo "✓ Dependencies installed"

clean: ## Clean generated files and dependencies
	@echo "Cleaning generated files..."
	@rm -rf node_modules
	@rm -f pnpm-lock.yaml
	@echo "✓ Cleaned"

##@ Dependency Management (Developer)

deps-check: install ## Check for available dependency updates
	@echo "Checking for dependency updates..."
	@pnpm run deps:check

deps-check-minor: install ## Check for minor version updates only
	@echo "Checking for minor version updates..."
	@pnpm run deps:check:minor

deps-check-patch: install ## Check for patch version updates only
	@echo "Checking for patch version updates..."
	@pnpm run deps:check:patch

deps-upgrade: install ## Upgrade all dependencies to latest versions (updates package.json)
	@echo "Upgrading all dependencies to latest versions..."
	@pnpm run deps:upgrade
	@echo "✓ Dependencies upgraded in package.json"
	@echo "  Run 'make install' to install updated dependencies"

deps-upgrade-minor: install ## Upgrade to latest minor versions (safer, updates package.json)
	@echo "Upgrading to latest minor versions..."
	@pnpm run deps:upgrade:minor
	@echo "✓ Dependencies upgraded in package.json"
	@echo "  Run 'make install' to install updated dependencies"

deps-upgrade-patch: install ## Upgrade to latest patch versions (safest, updates package.json)
	@echo "Upgrading to latest patch versions..."
	@pnpm run deps:upgrade:patch
	@echo "✓ Dependencies upgraded in package.json"
	@echo "  Run 'make install' to install updated dependencies"

deps-upgrade-interactive: install ## Interactively choose which dependencies to upgrade
	@echo "Interactive dependency upgrade..."
	@pnpm run deps:upgrade:interactive

audit: install ## Run security audit on dependencies
	@echo "Running security audit..."
	@pnpm run audit

audit-fix: install ## Automatically fix security vulnerabilities
	@echo "Fixing security vulnerabilities..."
	@pnpm run audit:fix
	@echo "✓ Security fixes applied"

audit-fix-force: install ## Force fix security vulnerabilities (may introduce breaking changes)
	@echo "Force fixing security vulnerabilities..."
	@pnpm audit --fix --force
	@echo "✓ Security fixes applied (with --force)"

security: audit ## Alias for audit (run security checks)

##@ Code Quality (Developer)

format: install ## Format all Markdown, JSON, and YAML files with Prettier
	@echo "Formatting files with Prettier..."
	@pnpm run format
	@echo "✓ Files formatted"

format-check: install ## Check formatting without making changes
	@echo "Checking file formatting..."
	@pnpm run format:check

format-md: install ## Format only Markdown files
	@echo "Formatting Markdown files..."
	@pnpm run format:md
	@echo "✓ Markdown files formatted"

lint: ## Run all linters (shellcheck + markdownlint)
	@echo "Running linters..."
	@$(MAKE) lint-shell
	@$(MAKE) lint-md
	@echo "✓ All linters passed"

lint-fix: install ## Run linters with auto-fix
	@echo "Running linters with auto-fix..."
	@pnpm run lint:md:fix
	@echo "✓ Linters completed"

lint-shell: ## Lint shell scripts with shellcheck
	@echo "Linting shell scripts..."
	@find scripts docker/lib -type f \( -name "*.sh" -o -name "*.extension" \) -exec shellcheck {} +
	@echo "✓ Shell scripts linted"

lint-md: install ## Lint Markdown files
	@echo "Linting Markdown files..."
	@pnpm run lint:md
	@echo "✓ Markdown files linted"

validate: lint format-check ## Run all validation checks (lint + format check)
	@echo "✓ All validation checks passed"

##@ Testing (Developer)

test: ## Run all tests
	@echo "Running all tests..."
	@$(MAKE) test-extensions
	@echo "✓ All tests passed"

test-extensions: ## Test extension system functionality
	@echo "Testing extensions..."
	@bash .github/scripts/extension-tests/test-api-compliance.sh
	@echo "✓ Extension tests passed"

test-workflows: ## Validate GitHub Actions workflow syntax
	@echo "Validating GitHub Actions workflows..."
	@for file in .github/workflows/*.yml; do \
		echo "  Checking $$file..."; \
		yamllint -d relaxed "$$file"; \
	done
	@echo "✓ Workflow validation complete"

##@ VM Operations (User/Operator)

vm-deploy: check-scripts ## Deploy new VM (usage: make vm-deploy APP_NAME=myapp REGION=sjc)
	@echo "Deploying VM: $(APP_NAME) in region $(REGION)..."
	@./scripts/vm-setup.sh --app-name $(APP_NAME) --region $(REGION)
	@echo "✓ VM deployed: $(APP_NAME)"
	@echo "  Connect: ssh developer@$(APP_NAME).fly.dev -p 10022"

vm-status: ## Check VM status
	@echo "Checking VM status: $(APP_NAME)..."
	@flyctl status -a $(APP_NAME)

vm-suspend: check-scripts ## Suspend VM to save costs
	@echo "Suspending VM: $(APP_NAME)..."
	@./scripts/vm-suspend.sh
	@echo "✓ VM suspended"

vm-resume: check-scripts ## Resume suspended VM
	@echo "Resuming VM: $(APP_NAME)..."
	@./scripts/vm-resume.sh
	@echo "✓ VM resumed"

vm-teardown: check-scripts ## Teardown VM and cleanup resources
	@echo "Tearing down VM: $(APP_NAME)..."
	@./scripts/vm-teardown.sh
	@echo "✓ VM removed"

vm-logs: ## View VM logs
	@echo "Viewing logs for $(APP_NAME)..."
	@flyctl logs -a $(APP_NAME)

##@ Monitoring (Operator)

cost-monitor: check-scripts ## Monitor Fly.io costs and usage
	@echo "Checking costs and usage..."
	@./scripts/cost-monitor.sh

backup: check-scripts ## Backup VM volume (usage: make backup APP_NAME=myapp)
	@echo "Backing up volume for $(APP_NAME)..."
	@./scripts/volume-backup.sh
	@echo "✓ Volume backed up"

restore: check-scripts ## Restore VM volume from backup
	@echo "Restoring volume for $(APP_NAME)..."
	@./scripts/volume-restore.sh
	@echo "✓ Volume restored"

##@ Documentation

docs: ## Generate all documentation
	@echo "Generating documentation..."
	@$(MAKE) bom-report
	@echo "✓ Documentation generated"

bom-report: check-scripts ## Generate Bill of Materials report
	@echo "Generating BOM report..."
	@./scripts/generate-bom-report.sh
	@echo "✓ BOM report generated"

##@ Quick Commands

ssh: ## SSH into VM (usage: make ssh APP_NAME=myapp)
	@echo "Connecting to $(APP_NAME)..."
	@ssh developer@$(APP_NAME).fly.dev -p 10022

ssh-fly: ## SSH via Fly.io hallpass (usage: make ssh-fly APP_NAME=myapp)
	@echo "Connecting to $(APP_NAME) via Fly.io..."
	@flyctl ssh console -a $(APP_NAME)

extensions-list: ## List available extensions
	@echo "Available extensions:"
	@grep -E "^[a-z-]+\.extension$$" docker/lib/extensions.d/* 2>/dev/null | sed 's/.*extensions\.d\//  - /' | sed 's/\.extension//' || echo "  (extension files not found)"

##@ Development Workflow

dev-setup: install format lint ## Complete development setup
	@echo "✓ Development environment ready"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Deploy a VM: make vm-deploy APP_NAME=myapp"
	@echo "  2. SSH into VM: make ssh APP_NAME=myapp"
	@echo "  3. Start coding!"

quick-start: ## Quick start guide
	@echo "Sindri Quick Start:"
	@echo ""
	@echo "1. Install dependencies:"
	@echo "   make install"
	@echo ""
	@echo "2. Deploy a VM:"
	@echo "   make vm-deploy APP_NAME=myapp REGION=sjc"
	@echo ""
	@echo "3. Connect to VM:"
	@echo "   make ssh APP_NAME=myapp"
	@echo ""
	@echo "4. For development:"
	@echo "   make dev-setup"
	@echo ""
	@echo "See 'make help' for all available commands"
