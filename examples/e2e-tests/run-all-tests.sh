#!/bin/bash

# Run all E2E tests for Thalamus examples
# This script starts all example applications and runs Playwright tests

set -e

echo "🚀 Starting Thalamus Examples E2E Test Suite"
echo ""

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
else
  echo "⚠️  .env file not found. Copying from .env.example..."
  cp .env.example .env
  echo "⚠️  Please configure .env file with your test credentials"
  exit 1
fi

# Check if Thalamus server is running
THALAMUS_URL="${THALAMUS_BASE_URL:-http://localhost:4000}"
echo "🔍 Checking Thalamus server at $THALAMUS_URL..."
if ! curl -s "$THALAMUS_URL/api/public/health" > /dev/null; then
  echo "❌ Thalamus server is not running"
  echo "   Start it with: cd ../../ && mix phx.server"
  exit 1
fi
echo "✅ Thalamus server is running"
echo ""

# Function to check if port is in use
check_port() {
  lsof -i :$1 > /dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
  local url=$1
  local name=$2
  local max_attempts=30
  local attempt=1

  echo "⏳ Waiting for $name to be ready at $url..."

  while [ $attempt -le $max_attempts ]; do
    if curl -s "$url" > /dev/null 2>&1; then
      echo "✅ $name is ready"
      return 0
    fi
    echo "   Attempt $attempt/$max_attempts..."
    sleep 2
    attempt=$((attempt + 1))
  done

  echo "❌ $name failed to start"
  return 1
}

# PIDs to track
PIDS=()

# Cleanup function
cleanup() {
  echo ""
  echo "🧹 Cleaning up..."
  for pid in "${PIDS[@]}"; do
    if ps -p $pid > /dev/null 2>&1; then
      echo "   Stopping process $pid"
      kill $pid 2>/dev/null || true
    fi
  done
  echo "✅ Cleanup complete"
}

trap cleanup EXIT INT TERM

# Start React SPA
echo "🚀 Starting React SPA..."
cd ../react-spa
if [ ! -d "node_modules" ]; then
  echo "   Installing dependencies..."
  npm install > /dev/null 2>&1
fi
if [ ! -f ".env" ]; then
  cp .env.example .env
fi
npm run dev > /tmp/react-spa.log 2>&1 &
PIDS+=($!)
cd ../e2e-tests
wait_for_service "http://localhost:${REACT_SPA_PORT:-5173}" "React SPA"

# Start Node.js Backend
echo "🚀 Starting Node.js Backend..."
cd ../nodejs-backend
if [ ! -d "node_modules" ]; then
  echo "   Installing dependencies..."
  npm install > /dev/null 2>&1
fi
if [ ! -f ".env" ]; then
  cp .env.example .env
fi
npm start > /tmp/nodejs-backend.log 2>&1 &
PIDS+=($!)
cd ../e2e-tests
wait_for_service "http://localhost:${NODEJS_PORT:-3000}/api/public/health" "Node.js Backend"

# Start Python FastAPI
echo "🚀 Starting Python FastAPI..."
cd ../python-fastapi
if [ ! -d "venv" ]; then
  echo "   Creating virtual environment..."
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt > /dev/null 2>&1
else
  source venv/bin/activate
fi
if [ ! -f ".env" ]; then
  cp .env.example .env
fi
python main.py > /tmp/fastapi.log 2>&1 &
PIDS+=($!)
cd ../e2e-tests
wait_for_service "http://localhost:${FASTAPI_PORT:-8000}" "Python FastAPI"

echo ""
echo "✅ All services started successfully"
echo ""

# Install Playwright if needed
if [ ! -d "node_modules" ]; then
  echo "📦 Installing test dependencies..."
  npm install
  npm run install
fi

echo "🧪 Running Playwright E2E tests..."
echo ""

# Run tests
if npm test; then
  echo ""
  echo "✅ All tests passed!"
  echo ""
  echo "📊 View HTML report: npm run report"
  exit 0
else
  echo ""
  echo "❌ Some tests failed"
  echo ""
  echo "📋 Debugging tips:"
  echo "   - View React SPA logs: tail -f /tmp/react-spa.log"
  echo "   - View Node.js logs: tail -f /tmp/nodejs-backend.log"
  echo "   - View FastAPI logs: tail -f /tmp/fastapi.log"
  echo "   - View test report: npm run report"
  exit 1
fi
