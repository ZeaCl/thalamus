#!/bin/bash

# ============================================================================
# ZEA Thalamus - Database Setup Script
# ============================================================================
# This script automates the database setup process for development and
# production environments.
#
# Usage:
#   ./scripts/setup.sh [environment]
#
# Arguments:
#   environment - dev (default), test, or prod
#
# Examples:
#   ./scripts/setup.sh          # Sets up development environment
#   ./scripts/setup.sh dev      # Sets up development environment
#   ./scripts/setup.sh test     # Sets up test environment
#   ./scripts/setup.sh prod     # Sets up production environment
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default environment
ENV="${1:-dev}"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}ZEA Thalamus - Database Setup${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo -e "${YELLOW}Environment: ${ENV}${NC}"
echo ""

# Validate environment
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENV'${NC}"
    echo -e "${YELLOW}Usage: $0 [dev|test|prod]${NC}"
    exit 1
fi

# Check if Elixir is installed
if ! command -v elixir &> /dev/null; then
    echo -e "${RED}Error: Elixir is not installed${NC}"
    echo -e "${YELLOW}Please install Elixir 1.17 or higher${NC}"
    exit 1
fi

# Check if Mix is available
if ! command -v mix &> /dev/null; then
    echo -e "${RED}Error: Mix is not available${NC}"
    exit 1
fi

# Set MIX_ENV
export MIX_ENV=$ENV

echo -e "${GREEN}✓${NC} Environment set to: ${ENV}"

# ============================================================================
# Install Dependencies
# ============================================================================
echo ""
echo -e "${BLUE}[1/6] Installing dependencies...${NC}"
mix deps.get

echo -e "${GREEN}✓${NC} Dependencies installed"

# ============================================================================
# Compile Application
# ============================================================================
echo ""
echo -e "${BLUE}[2/6] Compiling application...${NC}"
mix compile

echo -e "${GREEN}✓${NC} Application compiled"

# ============================================================================
# Create Database
# ============================================================================
echo ""
echo -e "${BLUE}[3/6] Creating database...${NC}"

if mix ecto.create; then
    echo -e "${GREEN}✓${NC} Database created"
else
    echo -e "${YELLOW}⚠${NC}  Database already exists or creation failed"
fi

# ============================================================================
# Run Migrations
# ============================================================================
echo ""
echo -e "${BLUE}[4/6] Running migrations...${NC}"
mix ecto.migrate

echo -e "${GREEN}✓${NC} Migrations completed"

# ============================================================================
# Seed Database (optional for development)
# ============================================================================
if [[ "$ENV" == "dev" ]]; then
    echo ""
    echo -e "${BLUE}[5/6] Seeding database with test data...${NC}"

    read -p "Do you want to seed the database with test data? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mix run priv/repo/seeds.exs
        echo -e "${GREEN}✓${NC} Database seeded"
    else
        echo -e "${YELLOW}⊘${NC} Database seeding skipped"
    fi
else
    echo ""
    echo -e "${YELLOW}[5/6] Skipping seed (not development environment)${NC}"
fi

# ============================================================================
# Verify Setup
# ============================================================================
echo ""
echo -e "${BLUE}[6/6] Verifying setup...${NC}"

# Check if we can connect to database
if mix ecto.rollback --step=0 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Database connection verified"
else
    echo -e "${RED}✗${NC} Database connection failed"
    exit 1
fi

# ============================================================================
# Display Summary
# ============================================================================
echo ""
echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo -e "Environment:  ${YELLOW}$ENV${NC}"
echo -e "Database:     ${YELLOW}thalamus_$ENV${NC}"
echo ""

if [[ "$ENV" == "dev" ]]; then
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Start the server:  ${YELLOW}mix phx.server${NC}"
    echo -e "  2. Visit:             ${YELLOW}http://localhost:4000${NC}"
    echo -e "  3. API Docs:          ${YELLOW}http://localhost:4000/api/docs${NC}"
    echo ""
    echo -e "${BLUE}Test Credentials (if seeded):${NC}"
    echo -e "  Admin Email:          ${YELLOW}admin@thalamus.dev${NC}"
    echo -e "  Admin Password:       ${YELLOW}AdminPassword123!${NC}"
elif [[ "$ENV" == "test" ]]; then
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  Run tests:  ${YELLOW}mix test${NC}"
elif [[ "$ENV" == "prod" ]]; then
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "  1. Configure secrets in config/runtime.exs"
    echo -e "  2. Build release:  ${YELLOW}MIX_ENV=prod mix release${NC}"
    echo -e "  3. Start server:   ${YELLOW}_build/prod/rel/thalamus/bin/thalamus start${NC}"
fi

echo ""
echo -e "${BLUE}============================================================================${NC}"
