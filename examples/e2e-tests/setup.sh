#!/bin/bash

# E2E Test Setup Script for Thalamus Examples
# This script sets up test OAuth2 clients and test users in Thalamus

set -e

echo "🔧 Setting up E2E test environment for Thalamus examples..."

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
else
  echo "⚠️  .env file not found. Please copy .env.example to .env and configure it."
  exit 1
fi

THALAMUS_URL="${THALAMUS_BASE_URL:-http://localhost:4000}"

echo "📡 Checking if Thalamus server is running at $THALAMUS_URL..."
if ! curl -s "$THALAMUS_URL/api/public/health" > /dev/null; then
  echo "❌ Thalamus server is not running at $THALAMUS_URL"
  echo "   Please start Thalamus first: cd ../../ && mix phx.server"
  exit 1
fi

echo "✅ Thalamus server is running"

echo ""
echo "📝 Creating test OAuth2 clients..."

# Function to create OAuth2 client via API
create_oauth2_client() {
  local name=$1
  local client_type=$2
  local grant_types=$3
  local redirect_uris=$4
  local scopes=$5

  echo "   Creating client: $name"

  # Note: This requires authentication to Thalamus API
  # You may need to adjust this based on your Thalamus API setup
  # For now, this is a placeholder - you'll need to create clients manually
  # or implement API authentication

  echo "   ⚠️  Please create this client manually in Thalamus dashboard:"
  echo "      - Name: $name"
  echo "      - Client Type: $client_type"
  echo "      - Grant Types: $grant_types"
  echo "      - Redirect URIs: $redirect_uris"
  echo "      - Scopes: $scopes"
  echo ""
}

# React SPA Client (Public)
create_oauth2_client \
  "E2E Test - React SPA" \
  "public" \
  "authorization_code,refresh_token" \
  "http://localhost:5173/callback" \
  "openid,profile,email,api:read"

# Node.js Backend Client (Confidential)
create_oauth2_client \
  "E2E Test - Node.js Backend" \
  "confidential" \
  "client_credentials" \
  "" \
  "api:read,api:write"

# Python FastAPI Client (Confidential)
create_oauth2_client \
  "E2E Test - Python FastAPI" \
  "confidential" \
  "client_credentials" \
  "" \
  "api:read,api:write"

echo "📝 Creating test user..."
echo "   Email: $TEST_USER_EMAIL"
echo "   Password: $TEST_USER_PASSWORD"
echo ""
echo "   ⚠️  Please create this user manually in Thalamus:"
echo "      1. Go to $THALAMUS_URL/dashboard/users"
echo "      2. Create user with email: $TEST_USER_EMAIL"
echo "      3. Set password: $TEST_USER_PASSWORD"
echo ""

echo "✅ Setup instructions displayed"
echo ""
echo "📋 Next steps:"
echo "   1. Create the OAuth2 clients and test user as shown above"
echo "   2. Update .env file with the generated client IDs and secrets"
echo "   3. Start example applications:"
echo "      - React SPA: cd ../react-spa && npm install && npm run dev"
echo "      - Node.js: cd ../nodejs-backend && npm install && npm run dev"
echo "      - FastAPI: cd ../python-fastapi && pip install -r requirements.txt && python main.py"
echo "   4. Run tests: npm test"
echo ""
echo "🎯 Manual setup required. See instructions above."
