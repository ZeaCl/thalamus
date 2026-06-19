# E2E Tests for Thalamus Examples

End-to-end tests using Playwright to verify that all Thalamus integration examples work correctly.

## Features

- ✅ **Playwright** - Modern E2E testing framework
- ✅ **Full OAuth2 Flow Testing** - Tests complete authorization flows
- ✅ **API Testing** - Tests backend endpoints
- ✅ **Browser Automation** - Tests React SPA user flows
- ✅ **Parallel Execution** - Fast test runs
- ✅ **HTML Reports** - Beautiful test reports with screenshots
- ✅ **CI/CD Ready** - Easy integration with GitHub Actions

## What's Tested

### React SPA (@react-spa)
- ✅ Home page loads correctly
- ✅ Login button appears when not authenticated
- ✅ Complete OAuth2 + PKCE authorization flow
- ✅ Token storage in localStorage
- ✅ Protected route access
- ✅ User profile display
- ✅ Logout functionality
- ✅ OAuth error handling

### Node.js Backend (@nodejs)
- ✅ Public health check endpoint
- ✅ M2M authentication with client credentials
- ✅ Protected endpoint access
- ✅ Token introspection
- ✅ Service token info retrieval
- ✅ Token caching performance

### Python FastAPI (@fastapi)
- ✅ Health check endpoints
- ✅ OpenAPI documentation availability
- ✅ Bearer token authentication
- ✅ Protected endpoint access with valid token
- ✅ Rejection of invalid/missing tokens
- ✅ M2M authentication flow
- ✅ Token introspection
- ✅ Pydantic model validation

## Prerequisites

1. **Thalamus server running** at `http://localhost:4000`
2. **Node.js 18+** installed
3. **Python 3.11+** installed (for FastAPI tests)
4. **Test OAuth2 clients** created in Thalamus
5. **Test user** created in Thalamus

## Setup

### 1. Install Dependencies

```bash
cd examples/e2e-tests
npm install
npm run install  # Install Playwright browsers
```

### 2. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` with your test configuration:

```env
# Thalamus Server
THALAMUS_BASE_URL=http://localhost:4000

# Test User (create in Thalamus dashboard)
TEST_USER_EMAIL=testuser@example.com
TEST_USER_PASSWORD=testpass123

# OAuth2 Clients (create in Thalamus dashboard)
REACT_SPA_CLIENT_ID=test_react_spa_client
NODEJS_CLIENT_ID=test_nodejs_client
NODEJS_CLIENT_SECRET=test_nodejs_secret
PYTHON_CLIENT_ID=test_python_client
PYTHON_CLIENT_SECRET=test_python_secret
```

### 3. Create Test OAuth2 Clients

Create the following OAuth2 clients in Thalamus dashboard (http://localhost:4000/dashboard/clients):

#### React SPA Client
- **Name**: "E2E Test - React SPA"
- **Client Type**: Public (no client secret)
- **Grant Types**: Authorization Code, Refresh Token
- **Redirect URIs**: `http://localhost:5173/callback`
- **Scopes**: `openid`, `profile`, `email`, `api:read`

#### Node.js Backend Client
- **Name**: "E2E Test - Node.js Backend"
- **Client Type**: Confidential (with client secret)
- **Grant Types**: Client Credentials
- **Scopes**: `api:read`, `api:write`

#### Python FastAPI Client
- **Name**: "E2E Test - Python FastAPI"
- **Client Type**: Confidential (with client secret)
- **Grant Types**: Client Credentials
- **Scopes**: `api:read`, `api:write`

### 4. Create Test User

Create a test user in Thalamus dashboard (http://localhost:4000/dashboard/users):

- **Email**: `testuser@example.com`
- **Password**: `testpass123`
- **Status**: Active

### 5. Update Example .env Files

Make sure each example has its `.env` file configured with the test client credentials:

```bash
# React SPA
cd ../react-spa
cp .env.example .env
# Edit .env with REACT_SPA_CLIENT_ID

# Node.js Backend
cd ../nodejs-backend
cp .env.example .env
# Edit .env with NODEJS_CLIENT_ID and NODEJS_CLIENT_SECRET

# Python FastAPI
cd ../python-fastapi
cp .env.example .env
# Edit .env with PYTHON_CLIENT_ID and PYTHON_CLIENT_SECRET
```

## Running Tests

### Quick Start - Run All Tests

```bash
# This script starts all services and runs all tests
./run-all-tests.sh
```

### Run Specific Test Suites

```bash
# Run only React SPA tests
npm run test:react-spa

# Run only Node.js tests
npm run test:nodejs

# Run only FastAPI tests
npm run test:fastapi
```

### Manual Testing (with headed browser)

```bash
# Start example services manually first
cd ../react-spa && npm run dev &
cd ../nodejs-backend && npm start &
cd ../python-fastapi && python main.py &

# Run tests with visible browser
npm run test:headed
```

### Interactive Mode

```bash
# Run tests in UI mode (great for debugging)
npm run test:ui
```

## Test Reports

After running tests:

```bash
# View HTML report with screenshots and videos
npm run report
```

The report shows:
- ✅ Pass/fail status for each test
- 📸 Screenshots on failure
- 🎥 Videos of failed tests
- ⏱️ Test execution times
- 📊 Overall statistics

## Project Structure

```
e2e-tests/
├── tests/
│   ├── react-spa.spec.js       # React SPA E2E tests
│   ├── nodejs-backend.spec.js  # Node.js API tests
│   └── python-fastapi.spec.js  # FastAPI API tests
├── playwright.config.js         # Playwright configuration
├── package.json                 # Test dependencies
├── .env.example                 # Environment template
├── setup.sh                     # Setup helper script
├── run-all-tests.sh            # Automated test runner
└── README.md                    # This file
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/e2e-tests.yml`:

```yaml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.17'
          otp-version: '26'

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Start Thalamus Server
        run: |
          cd ../..
          mix deps.get
          mix ecto.create
          mix ecto.migrate
          mix phx.server &

      - name: Run E2E Tests
        run: |
          cd examples/e2e-tests
          npm install
          npm run install
          ./run-all-tests.sh

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: examples/e2e-tests/playwright-report/
```

## Troubleshooting

### "Thalamus server is not running"

```bash
# Start Thalamus
cd ../../
mix phx.server
```

### "Service failed to start"

Check service logs:
```bash
tail -f /tmp/react-spa.log
tail -f /tmp/nodejs-backend.log
tail -f /tmp/fastapi.log
```

### "OAuth2 client not found"

Make sure you've created all test OAuth2 clients in Thalamus dashboard and updated the `.env` file with the correct client IDs and secrets.

### "Test user authentication failed"

1. Verify test user exists in Thalamus
2. Check email and password match `.env` configuration
3. Ensure user account is active

### "Port already in use"

Kill processes on conflicting ports:
```bash
lsof -ti:5173 | xargs kill  # React SPA
lsof -ti:3000 | xargs kill  # Node.js
lsof -ti:8000 | xargs kill  # FastAPI
```

## Writing New Tests

### Example Test Structure

```javascript
import { test, expect } from '@playwright/test'

test.describe('My Feature @my-tag', () => {
  test('should do something', async ({ page }) => {
    await page.goto('http://localhost:5173')
    await expect(page.locator('h1')).toContainText('Expected Text')
  })
})
```

### Best Practices

1. **Use descriptive test names** - "should complete OAuth2 login flow"
2. **Add tags** - Use `@react-spa`, `@nodejs`, `@fastapi` for filtering
3. **Clean up state** - Logout after authentication tests
4. **Use helpers** - Extract common operations (login, get token)
5. **Assert on data** - Verify API responses have correct structure
6. **Handle async** - Use `await` for all async operations

## Performance Tips

- Tests run sequentially to avoid port conflicts
- Token caching reduces test execution time
- Use `--headed` only for debugging
- Run specific test suites instead of all tests during development

## Learn More

- [Playwright Documentation](https://playwright.dev/)
- [Playwright Test](https://playwright.dev/docs/test-intro)
- [Playwright API Testing](https://playwright.dev/docs/test-api-testing)
- [Thalamus Documentation](../../docs/README.md)
