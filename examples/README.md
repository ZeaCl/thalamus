# Thalamus Examples

This directory contains example applications demonstrating how to integrate with Thalamus OAuth2/OIDC server using the official **@zea.cl/thalamus-js** SDK.

## Official SDK

All examples use the official Thalamus JavaScript/TypeScript SDK:

```bash
npm install @zea.cl/thalamus-js
```

**SDK Repository**: https://github.com/chinostroza/thalamus-js
**NPM Package**: https://www.npmjs.com/package/@zea.cl/thalamus-js
**Documentation**: See `/Users/dev/Documents/zea/thalamus-js/README.md`

## Available Examples

### 1. Next.js App Router (`nextjs-app-router/`)
Full-stack Next.js application using:
- Next.js 15 App Router
- NextAuth.js for OAuth2 authentication
- Server and Client components
- Protected routes and API endpoints

### 2. React SPA (`react-spa/`)
Single Page Application using:
- React 18 + Vite
- Authorization Code Flow with PKCE
- Token management and refresh
- Protected routes

### 3. Node.js Backend (`nodejs-backend/`)
Backend API server using:
- Express.js
- Client Credentials flow (M2M)
- Token introspection
- Protected endpoints

### 4. Python FastAPI (`python-fastapi/`)
Python backend using:
- FastAPI framework
- OAuth2 client credentials
- JWT validation
- Agent tokens support

### 5. Elixir Phoenix (`elixir-phoenix/`)
Phoenix application using:
- Phoenix LiveView
- OAuth2 client library
- Session management
- Real-time updates

## Quick Start

Each example has its own README with:
- Installation instructions
- Configuration steps
- Running instructions
- Key concepts explained

## Prerequisites

1. **Running Thalamus instance**
   ```bash
   cd /path/to/thalamus
   mix phx.server
   # Server runs at http://localhost:4000
   ```

2. **Create OAuth2 Client**
   - Go to http://localhost:4000/dashboard/clients
   - Click "New Client"
   - Configure redirect URIs based on example
   - Save client_id and client_secret

3. **Configure Example**
   - Copy `.env.example` to `.env`
   - Add your client_id and client_secret
   - Update redirect URIs if needed

## Common Configuration

All examples use these default settings:

```env
THALAMUS_BASE_URL=http://localhost:4000
THALAMUS_CLIENT_ID=your_client_id
THALAMUS_CLIENT_SECRET=your_client_secret
```

## OAuth2 Flows Demonstrated

- **Authorization Code Flow**: Web applications (Next.js, React)
- **Authorization Code + PKCE**: Public clients (React SPA)
- **Client Credentials**: Backend services (Node.js, Python)
- **Refresh Token**: Long-lived sessions
- **Agent Tokens**: Multi-agent delegation (advanced)

## End-to-End Testing

All examples include comprehensive E2E tests using **Playwright**:

```bash
cd e2e-tests

# Quick start - runs all tests
./run-all-tests.sh

# Or run specific tests
npm run test:react-spa   # React SPA tests
npm run test:nodejs      # Node.js backend tests
npm run test:fastapi     # Python FastAPI tests

# View test report
npm run report
```

**What's tested:**
- ✅ Complete OAuth2 authorization flows
- ✅ PKCE implementation
- ✅ Token management and caching
- ✅ Protected routes and endpoints
- ✅ User authentication flows
- ✅ API endpoint functionality
- ✅ Error handling

See [`e2e-tests/README.md`](./e2e-tests/README.md) for detailed testing documentation.

## Support

- Documentation: `/docs`
- Issues: https://github.com/chinostroza/thalamus/issues
- Thalamus API: http://localhost:4000/api/docs
