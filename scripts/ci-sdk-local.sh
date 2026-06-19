#!/bin/bash
# scripts/ci-sdk-local.sh
# Runs all the SDK CI checks locally to verify everything is passing before pushing.

# Exit on first failure
set -e

# Clear screen
clear

echo "===================================================="
echo "        RUNNING LOCAL SDK CI PIPELINE CHECKS        "
echo "===================================================="
echo ""

# Helper function to print headers
print_step() {
  echo -e "\n\033[1;34m==>\033[0m \033[1;37m$1...\033[0m"
}

# Go to sdk directory relative to the script location
cd "$(dirname "$0")/../sdk"

# 1. Install dependencies
print_step "1. Installing Node dependencies"
npm install
echo -e "\033[0;32m✓ Dependencies installed successfully\033[0m"

# 2. Check TypeScript types
print_step "2. Checking TypeScript types"
npm run typecheck
echo -e "\033[0;32m✓ Type checking passed\033[0m"

# 3. Run unit tests
print_step "3. Running unit tests"
npm run test:unit
echo -e "\033[0;32m✓ All unit tests passed successfully\033[0m"

echo ""
echo "===================================================="
echo "  🎉 SUCCESS: All required SDK CI checks passed locally! "
echo "===================================================="
