# ============================================================================
# ZEA Thalamus - Makefile
# ============================================================================
# Convenience commands for development, testing, and deployment
#
# Usage: make [command]
# ============================================================================

.PHONY: help setup dev test clean docker-build docker-up docker-down migrate seed

# Default target
.DEFAULT_GOAL := help

# ============================================================================
# Help
# ============================================================================
help: ## Show this help message
	@echo "ZEA Thalamus - Available Commands"
	@echo "=================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# Development Setup
# ============================================================================
setup: ## Initial project setup (install deps, create DB, migrate)
	@./scripts/setup.sh dev

setup-test: ## Setup test environment
	@./scripts/setup.sh test

setup-prod: ## Setup production environment
	@./scripts/setup.sh prod

deps: ## Install dependencies
	@mix deps.get

compile: ## Compile the project
	@mix compile

# ============================================================================
# Development
# ============================================================================
dev: ## Start development server
	@mix phx.server

dev-iex: ## Start development server with IEx shell
	@iex -S mix phx.server

console: ## Start IEx console
	@iex -S mix

format: ## Format code
	@mix format

lint: ## Run linter (Credo)
	@mix credo --strict

# ============================================================================
# Database
# ============================================================================
db-create: ## Create database
	@mix ecto.create

db-drop: ## Drop database
	@mix ecto.drop

db-migrate: ## Run pending migrations
	@mix ecto.migrate

db-rollback: ## Rollback last migration
	@mix ecto.rollback

db-reset: ## Drop, create, and migrate database
	@mix ecto.reset

db-seed: ## Seed database with test data
	@mix run priv/repo/seeds.exs

db-status: ## Show migration status
	@mix ecto.migrations

# ============================================================================
# Testing
# ============================================================================
test: ## Run all tests
	@MIX_ENV=test mix test

test-watch: ## Run tests in watch mode
	@MIX_ENV=test mix test.watch

test-coverage: ## Run tests with coverage report
	@MIX_ENV=test mix test --cover

test-controllers: ## Run only controller tests
	@MIX_ENV=test mix test test/thalamus_web/controllers/

test-domain: ## Run only domain tests
	@MIX_ENV=test mix test test/thalamus/domain/

test-integration: ## Run only integration tests
	@MIX_ENV=test mix test --only integration

# ============================================================================
# Docker
# ============================================================================
docker-build: ## Build Docker image
	@docker-compose build

docker-up: ## Start all services with Docker Compose
	@docker-compose up -d

docker-down: ## Stop all Docker services
	@docker-compose down

docker-logs: ## Show Docker logs
	@docker-compose logs -f thalamus

docker-shell: ## Open shell in thalamus container
	@docker-compose exec thalamus sh

docker-psql: ## Open PostgreSQL shell
	@docker-compose exec postgres psql -U postgres -d thalamus_dev

docker-redis: ## Open Redis CLI
	@docker-compose exec redis redis-cli -a redis_password

docker-clean: ## Remove all Docker containers, volumes, and images
	@docker-compose down -v
	@docker system prune -f

docker-prod-build: ## Build production Docker image
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

docker-prod-up: ## Start production environment
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# ============================================================================
# Code Quality
# ============================================================================
dialyzer: ## Run Dialyzer (static analysis)
	@mix dialyzer

check: format lint test ## Run all code quality checks

# ============================================================================
# Release
# ============================================================================
release-build: ## Build production release
	@MIX_ENV=prod mix release

release-run: ## Run production release
	@_build/prod/rel/thalamus/bin/thalamus start

# ============================================================================
# Cleanup
# ============================================================================
clean: ## Clean build artifacts
	@mix clean
	@rm -rf _build deps

clean-all: clean ## Clean everything including node modules
	@rm -rf assets/node_modules
	@rm -rf priv/static/assets

# ============================================================================
# Documentation
# ============================================================================
docs: ## Generate documentation
	@mix docs

docs-open: docs ## Generate and open documentation
	@open doc/index.html

# ============================================================================
# Utilities
# ============================================================================
routes: ## Show all routes
	@mix phx.routes

outdated: ## Show outdated dependencies
	@mix hex.outdated

security: ## Run security audit
	@mix deps.audit

# ============================================================================
# CI/CD
# ============================================================================
ci: deps compile lint test ## Run CI pipeline locally
	@echo "CI pipeline completed successfully!"
