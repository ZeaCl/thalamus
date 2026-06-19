#!/bin/bash
# scripts/ci-local.sh
# Runs all the CI checks locally to verify everything is passing before pushing.

# Exit on first failure
set -e

# Clear screen
clear

echo "===================================================="
echo "          RUNNING LOCAL CI PIPELINE CHECKS          "
echo "===================================================="
echo ""

# Helper function to print headers
print_step() {
  echo -e "\n\033[1;34m==>\033[0m \033[1;37m$1...\033[0m"
}

# 1. Formatting Check
print_step "1. Checking code formatting"
mix format --check-formatted
echo -e "\033[0;32m✓ Formatting is correct\033[0m"

# 2. Credo Linter
print_step "2. Running Credo (linter)"
# We run without failing on warning if you want, but CI has `continue-on-error: true`
# Here we will let it run and show results
mix credo --strict || true
echo -e "\033[0;32m✓ Credo checks completed (non-blocking)\033[0m"

# 3. Compilation with Warnings as Errors (Dev)
print_step "3. Compiling in DEV mode (warnings as errors)"
mix compile --warnings-as-errors
echo -e "\033[0;32m✓ DEV compilation passed without warnings\033[0m"

# 4. Compilation with Warnings as Errors (Test)
print_step "4. Compiling in TEST mode (warnings as errors)"
MIX_ENV=test mix compile --warnings-as-errors
echo -e "\033[0;32m✓ TEST compilation passed without warnings\033[0m"

# 5. Database Setup & Tests
print_step "5. Running tests and coverage"
# This will automatically run ecto.create and ecto.migrate for the test DB
MIX_ENV=test mix test --cover
echo -e "\033[0;32m✓ All tests passed successfully\033[0m"

# 6. Dependency Audit
print_step "6. Auditing Hex dependencies for vulnerabilities"
mix deps.audit || echo -e "\033[0;33m⚠ Audit warnings found (non-blocking in CI)\033[0m"

# 7. Hex Audit (Retired Packages)
print_step "7. Auditing Hex packages for retired packages"
mix hex.audit || echo -e "\033[0;33m⚠ Hex audit warnings found (non-blocking in CI)\033[0m"

# 8. Dialyzer (Static Analysis)
print_step "8. Running Dialyzer (Static Analysis)"
echo "Note: This might take a few minutes if PLTs need to be built."
mix dialyzer || echo -e "\033[0;33m⚠ Dialyzer warnings found (non-blocking in CI)\033[0m"

echo ""
echo "===================================================="
echo "  🎉 SUCCESS: All required CI checks passed locally! "
echo "===================================================="
