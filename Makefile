# Helix Docker Development Makefile
# Convenient shortcuts for Docker development commands

.PHONY: help start stop restart build rebuild shell logs clean status test analyze pub-get code-gen doctor deps-check deps-update deps-audit deps-outdated

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Helix Docker Development Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make start        # Start development environment"
	@echo "  make shell        # Open shell in container"
	@echo "  make test         # Run all tests"
	@echo "  make logs         # View logs"

start: ## Start all development containers
	@./scripts/docker-dev.sh start

stop: ## Stop all development containers
	@./scripts/docker-dev.sh stop

restart: ## Restart all development containers
	@./scripts/docker-dev.sh restart

build: ## Build or rebuild containers
	@./scripts/docker-dev.sh build

rebuild: ## Force rebuild all containers from scratch
	@./scripts/docker-dev.sh rebuild

shell: ## Open a bash shell in the Flutter development container
	@./scripts/docker-dev.sh shell

logs: ## Show logs from all containers
	@./scripts/docker-dev.sh logs

clean: ## Remove all containers and volumes (WARNING: destroys data)
	@./scripts/docker-dev.sh clean

status: ## Show status of all containers
	@./scripts/docker-dev.sh status

# Flutter commands
test: ## Run all tests
	@./scripts/docker-test.sh all

test-unit: ## Run unit tests only
	@./scripts/docker-test.sh unit

test-widget: ## Run widget tests only
	@./scripts/docker-test.sh widget

test-integration: ## Run integration tests only
	@./scripts/docker-test.sh integration

test-coverage: ## Run tests with coverage report
	@./scripts/docker-test.sh coverage

analyze: ## Run Flutter analyze
	@./scripts/docker-dev.sh analyze

pub-get: ## Run flutter pub get
	@./scripts/docker-dev.sh pub-get

code-gen: ## Run build_runner code generation
	@./scripts/docker-dev.sh code-gen

doctor: ## Run flutter doctor
	@./scripts/docker-dev.sh doctor

# Quick development commands
dev: start shell ## Start environment and open shell

run: ## Run the Flutter app
	@./scripts/docker-dev.sh flutter run

# Utility commands
ps: ## List running containers
	@docker compose ps

exec: ## Execute a command in the dev container (usage: make exec CMD="flutter --version")
	@docker compose exec flutter-dev $(CMD)

# Database commands
db-shell: ## Open PostgreSQL shell
	@docker compose exec postgres psql -U helix -d helix_dev

db-backup: ## Backup PostgreSQL database
	@docker compose exec postgres pg_dump -U helix helix_dev > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Database backed up to backup_$(shell date +%Y%m%d_%H%M%S).sql"

# Redis commands
redis-cli: ## Open Redis CLI
	@docker compose exec redis redis-cli

# Nginx commands
nginx-reload: ## Reload Nginx configuration
	@docker compose exec nginx nginx -s reload

# Cleanup commands
prune: ## Clean up Docker system (remove unused images, containers, etc.)
	@docker system prune -f

prune-all: ## Aggressive Docker cleanup (WARNING: removes all unused data)
	@docker system prune -a -f --volumes

# Setup commands
setup: build pub-get code-gen ## Initial setup: build, get deps, and generate code
	@echo "$(GREEN)Setup complete! Run 'make start' to begin development.$(NC)"

# CI/CD
ci-test: ## Run tests in CI mode (no interactive shell)
	@docker compose run --rm flutter-dev flutter test

ci-analyze: ## Run analysis in CI mode
	@docker compose run --rm flutter-dev flutter analyze

# Documentation
docs: ## Start documentation server
	@echo "$(BLUE)Starting documentation server at http://localhost:8000$(NC)"
	@docker compose up -d docs

docs-stop: ## Stop documentation server
	@docker compose stop docs

# Security Commands
security-check: ## Run all security checks
	@echo "$(BLUE)Running comprehensive security checks...$(NC)"
	@./scripts/security-check.sh all

security-audit: ## Audit dependencies for vulnerabilities
	@echo "$(BLUE)Auditing dependencies for vulnerabilities...$(NC)"
	@./scripts/security-check.sh audit

security-secrets: ## Scan for hardcoded secrets
	@echo "$(BLUE)Scanning for hardcoded secrets...$(NC)"
	@./scripts/security-check.sh secrets

security-sast: ## Run static application security testing
	@echo "$(BLUE)Running static security analysis...$(NC)"
	@./scripts/security-check.sh sast

security-licenses: ## Check dependency licenses
	@echo "$(BLUE)Checking dependency licenses...$(NC)"
	@./scripts/security-check.sh licenses

security-full: ## Run full security scan (all checks)
	@echo "$(BLUE)Running full security scan...$(NC)"
	@./scripts/security-check.sh full

security-report: ## Generate security report
	@echo "$(BLUE)Generating security report...$(NC)"
	@./scripts/security-check.sh report

# Dependency Management Commands
deps-check: ## Verify all dependencies and lockfiles
	@echo "$(BLUE)Running comprehensive dependency check...$(NC)"
	@./scripts/deps-check.sh

deps-update: ## Update dependencies (usage: make deps-update TYPE=minor)
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@./scripts/deps-update.sh $(or $(TYPE),minor)

deps-audit: ## Run security audit on all dependencies
	@echo "$(BLUE)Running dependency security audit...$(NC)"
	@./scripts/deps-audit.sh

deps-outdated: ## Check for outdated dependencies
	@echo "$(BLUE)Checking for outdated dependencies...$(NC)"
	@flutter pub outdated
	@echo ""
	@echo "$(BLUE)iOS CocoaPods:$(NC)"
	@cd ios && pod outdated || true
	@echo ""
	@echo "$(BLUE)macOS CocoaPods:$(NC)"
	@cd macos && pod outdated || true

deps-install: ## Install all dependencies (Flutter + CocoaPods)
	@echo "$(BLUE)Installing Flutter dependencies...$(NC)"
	@flutter pub get
	@echo ""
	@echo "$(BLUE)Installing iOS dependencies...$(NC)"
	@cd ios && pod install
	@echo ""
	@echo "$(BLUE)Installing macOS dependencies...$(NC)"
	@cd macos && pod install
	@echo ""
	@echo "$(GREEN)All dependencies installed!$(NC)"

deps-clean: ## Clean all dependency caches
	@echo "$(BLUE)Cleaning Flutter pub cache...$(NC)"
	@flutter pub cache repair
	@echo ""
	@echo "$(BLUE)Cleaning CocoaPods cache...$(NC)"
	@pod cache clean --all || true
	@echo ""
	@echo "$(BLUE)Removing generated files...$(NC)"
	@rm -rf ios/Pods ios/.symlinks
	@rm -rf macos/Pods macos/.symlinks
	@echo ""
	@echo "$(GREEN)Dependency caches cleaned!$(NC)"
	@echo "Run 'make deps-install' to reinstall dependencies"
