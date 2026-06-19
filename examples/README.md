<<<<<<< HEAD
# Thalamus OAuth2 Examples

This directory contains example applications demonstrating different ways to integrate with ZEA Thalamus OAuth2 server.

## Available Examples

### 1. Next.js 14 App Router ([nextjs-app-router](./nextjs-app-router))

**Best for:** Modern Next.js applications using App Router

Complete Next.js 14 example using the `@zea/thalamus-js` SDK with:
- OAuth2 Authorization Code flow
- Server Components for protected routes
- httpOnly cookies for token storage
- TypeScript SDK integration
- Production-ready security patterns

**Tech Stack:**
- Next.js 14 (App Router)
- React 18
- TypeScript
- @zea/thalamus-js SDK

[View Example →](./nextjs-app-router)

---

### 2. Direct API Example ([direct-api](./direct-api))

**Best for:** Understanding OAuth2 internals or integrating with languages without SDKs

Simple Express.js server demonstrating OAuth2 integration using **direct HTTP API calls** (no SDK):
- Vanilla `fetch()` calls to all OAuth2 endpoints
- Step-by-step OAuth2 flow explained
- Language-agnostic pattern
- Easy to adapt to Python, Go, PHP, etc.

**Tech Stack:**
- Express.js
- TypeScript
- Native `fetch()` API
- No external OAuth libraries

[View Example →](./direct-api)

---

## Quick Comparison

| Feature | Next.js Example | Direct API Example |
|---------|----------------|-------------------|
| **SDK** | ✅ Uses @zea/thalamus-js | ❌ No SDK, raw HTTP |
| **Complexity** | Simple (SDK abstracts OAuth2) | Educational (shows all details) |
| **Best for** | Production apps | Learning/Custom integrations |
| **Language** | TypeScript/JavaScript | Any (pattern is universal) |
| **Framework** | Next.js 14 | Express.js |
| **Security** | Built-in best practices | Manual implementation |

## Which Example Should I Use?

### Choose **Next.js Example** if:
- You're building a Next.js application
- You want the fastest integration
- You prefer using a well-tested SDK
- You're deploying to production soon

### Choose **Direct API Example** if:
- You want to understand OAuth2 deeply
- You're integrating with a language we don't have an SDK for
- You need full control over HTTP requests
- You're building your own SDK

### Use **Both** if:
- You want to see the difference between SDK and raw API
- You're learning OAuth2 and want to see both approaches

## Getting Started

Each example has its own README with detailed setup instructions:

1. **Next.js Example**: [examples/nextjs-app-router/README.md](./nextjs-app-router/README.md)
2. **Direct API Example**: [examples/direct-api/README.md](./direct-api/README.md)

## Prerequisites

All examples require:

1. **Thalamus Server Running**
   ```bash
   # In the Thalamus root directory
   mix phx.server
   ```
   Server will be available at `http://localhost:4000`

2. **OAuth2 Client Registered**

   You need to create an OAuth2 client in Thalamus. You can do this via:
   - Admin API endpoint
   - Database seed script
   - Thalamus admin interface

   Required client configuration:
   - Client ID and Secret
   - Redirect URI (different for each example):
     - Next.js: `http://localhost:3000/auth/callback`
     - Direct API: `http://localhost:3001/auth/callback`
   - Allowed scopes: `openid profile email`
   - Grant type: `authorization_code`

## Common Setup Steps

### 1. Configure Thalamus Client

Both examples need OAuth2 client credentials. Create a client in Thalamus with:

```elixir
# In Thalamus IEx console (iex -S mix phx.server)
alias Thalamus.Infrastructure.Persistence.OAuth2ClientSchema
alias Thalamus.Repo

{:ok, client} = %OAuth2ClientSchema{
  name: "Example Application",
  client_id: "example_client_id",
  client_secret: "example_client_secret",
  redirect_uris: [
    "http://localhost:3000/auth/callback",  # Next.js
    "http://localhost:3001/auth/callback"   # Direct API
  ],
  allowed_grant_types: ["authorization_code", "refresh_token"],
  allowed_scopes: ["openid", "profile", "email"],
  is_confidential: true,
  organization_id: nil
} |> Repo.insert()
```

### 2. Configure Environment Variables

Each example has an `.env.example` file. Copy it to `.env` or `.env.local` and fill in your values.

## OAuth2 Flow Overview

Both examples implement the same OAuth2 Authorization Code flow:

```
┌─────────┐                                  ┌──────────┐
│         │                                  │          │
│ Browser │                                  │ Thalamus │
│         │                                  │          │
└────┬────┘                                  └────┬─────┘
     │                                            │
     │  1. Click "Sign In"                       │
     ├──────────────────────────────────────────►│
     │     GET /oauth/authorize                  │
     │                                            │
     │  2. Show Login Form                       │
     │◄───────────────────────────────────────── │
     │                                            │
     │  3. Submit Credentials                    │
     ├──────────────────────────────────────────►│
     │     POST /oauth/authorize                 │
     │                                            │
     │  4. Redirect with Code                    │
     │◄──────────────────────────────────────────│
     │     ?code=xxx&state=xxx                   │
     │                                            │
┌────▼────┐                                      │
│         │                                      │
│   App   │  5. Exchange Code for Token         │
│ Server  ├─────────────────────────────────────►│
│         │     POST /oauth/token                │
│         │                                      │
│         │  6. Return Access Token              │
│         │◄─────────────────────────────────────┤
│         │     {access_token, ...}              │
└────┬────┘                                      │
     │                                            │
     │  7. Redirect to Dashboard                 │
     │◄───────────────────────────────────────── │
     │                                            │
     │  8. GET /dashboard                        │
     │     (with access_token cookie)            │
     ├──────────────────────────────────────────►│
     │     GET /oauth/userinfo                   │
     │     Authorization: Bearer <token>         │
     │                                            │
     │  9. Return User Data                      │
     │◄──────────────────────────────────────────┤
     │     {sub, email, name, ...}               │
     │                                            │
```

## Security Best Practices

All examples implement:

- ✅ **CSRF Protection**: State parameter validation
- ✅ **XSS Protection**: httpOnly cookies (tokens not accessible to JavaScript)
- ✅ **Secure Cookies**: HTTPS-only in production
- ✅ **Token Revocation**: Proper logout with token cleanup
- ✅ **Server-Side Validation**: Tokens validated on server, not client

## API Endpoints Used

All examples interact with these Thalamus endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/oauth/authorize` | GET | Start OAuth2 flow |
| `/oauth/token` | POST | Exchange code for tokens |
| `/oauth/userinfo` | GET | Get user information |
| `/oauth/introspect` | POST | Validate token |
| `/oauth/revoke` | POST | Revoke token |

See [Direct API Example README](./direct-api/README.md) for detailed HTTP request/response examples.

## SDK Package

The `@zea/thalamus-js` SDK used in the Next.js example is located in:

```
packages/thalamus-js/
```

See [SDK README](../packages/thalamus-js/README.md) for full documentation.

## Troubleshooting

### "Invalid redirect_uri" error

Make sure the redirect URI in your `.env` file matches **exactly** what's configured in your Thalamus OAuth2 client (including protocol, port, and path).

### "Invalid client" error

- Verify `THALAMUS_CLIENT_ID` and `THALAMUS_CLIENT_SECRET` are correct
- Check that the client exists in Thalamus database

### "Connection refused" to Thalamus

- Ensure Thalamus server is running: `mix phx.server`
- Verify `THALAMUS_BASE_URL` is correct (default: `http://localhost:4000`)

### Cookies not being set

- Check browser console for cookie errors
- Ensure `sameSite: 'lax'` is set (required for OAuth redirects)
- In production, use HTTPS and `secure: true`

## Contributing

Have an example in another framework or language? Pull requests are welcome!

Potential examples we'd love to see:
- React SPA with Vite
- Vue.js application
- Python Flask/Django
- Go web application
- Ruby on Rails
- Mobile apps (React Native, Flutter)

## Learn More

- [Thalamus Documentation](http://localhost:4000/docs)
- [OAuth 2.0 Specification (RFC 6749)](https://datatracker.ietf.org/doc/html/rfc6749)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [OAuth 2.0 Security Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)

## License

MIT
=======
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
>>>>>>> bc0196c (feat: JWT RS256 + JWKS + domain scopes + service accounts)
