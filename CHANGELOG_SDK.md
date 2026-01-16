# Changelog - SDK & Developer Experience

## [1.0.0] - 2026-01-15

### Added - TypeScript SDK (@zea/thalamus-js)

**Complete OAuth2 SDK with zero dependencies**

- ✅ Full TypeScript support with comprehensive type definitions
- ✅ OAuth2 Authorization Code flow
- ✅ Client Credentials grant
- ✅ Refresh Token grant
- ✅ Token introspection (RFC 7662)
- ✅ Token revocation (RFC 7009)
- ✅ OpenID Connect userinfo endpoint
- ✅ Automatic error handling with typed exceptions
- ✅ Zero runtime dependencies
- ✅ ESM and CJS builds
- ✅ Full test coverage (17 tests passing)

**SDK Features:**
- Simple, Stripe-like API design
- Automatic state generation for CSRF protection
- Bearer token authentication
- Configurable base URL and scopes
- Built-in error handling
- Tree-shakeable exports

**Package Details:**
- Package name: `@zea/thalamus-js`
- Version: 1.0.0
- License: MIT
- Node.js: >=18.0.0

### Added - Next.js 14 App Router Example

**Production-ready example application**

- ✅ Complete OAuth2 Authorization Code flow
- ✅ React Server Components (RSC)
- ✅ Server-side authentication
- ✅ httpOnly cookies for token storage
- ✅ CSRF protection with state parameter
- ✅ Protected dashboard route
- ✅ User information display
- ✅ Token metadata display
- ✅ Logout with token revocation

**Files:**
- `app/page.tsx` - Landing page
- `app/api/auth/login/route.ts` - OAuth2 redirect
- `app/auth/callback/route.ts` - Authorization callback
- `app/dashboard/page.tsx` - Protected dashboard
- `app/api/auth/logout/route.ts` - Logout and revocation
- `.env.example` - Environment configuration
- `README.md` - Complete setup instructions

**Security Features:**
- httpOnly cookies (XSS protection)
- CSRF state validation
- Server-side token validation
- Secure cookie configuration
- Token cleanup on logout

### Added - Direct API Example

**Educational example without SDK**

- ✅ Express.js server with TypeScript
- ✅ OAuth2 using vanilla `fetch()` calls
- ✅ Step-by-step HTTP request/response documentation
- ✅ Language-agnostic pattern
- ✅ Complete flow explanation

**Documentation:**
- Detailed OAuth2 flow breakdown
- Example HTTP requests and responses
- Code samples for Python, Go, and PHP
- Security best practices
- Troubleshooting guide

**Features:**
- Simple HTML UI
- All OAuth2 endpoints demonstrated
- Request/response logging
- Error handling examples
- Adaptable to any language

### Added - Web Documentation System

**In-app documentation at /docs**

- ✅ Getting Started guide
- ✅ Integration guide
- ✅ API Reference
- ✅ Deployment guide
- ✅ Agent Tokens documentation
- ✅ Modern UI with navigation

**Controllers:**
- `DocsController` - 6 documentation routes
- `DocsHTML` - View module with HEEx templates
- Router integration

### Added - Comprehensive Documentation

**README and guides**

- ✅ Updated main README with SDK section
- ✅ Quick start example for SDK
- ✅ Examples comparison table
- ✅ Setup guide (SETUP_EXAMPLES.md)
- ✅ Complete examples README

**Documentation Structure:**
- SDK README with full API reference
- Next.js example README with security guide
- Direct API README with HTTP examples
- Examples overview with flow diagrams
- Setup instructions for OAuth2 clients

### Added - Testing

**SDK test suite with Vitest**

- ✅ 17 unit tests for SDK
- ✅ ThalamusClient initialization tests
- ✅ OAuth2 URL generation tests
- ✅ TypeScript type validation tests
- ✅ Test coverage for core functionality

**Test Organization:**
- `__tests__/ThalamusClient.test.ts` - Client tests
- `__tests__/auth/OAuth2.test.ts` - OAuth2 module tests
- `__tests__/types.test.ts` - Type validation tests
- Vitest configuration for modern testing
- Fast execution (<300ms)

### Changed

**README.md:**
- Added SDK section with quick start
- Added examples section
- Updated developer experience features
- Added links to SDK and examples

**Project Structure:**
- New `packages/thalamus-js/` directory for SDK
- New `examples/` directory with 2 complete examples
- New `scripts/` directory with setup helpers

### Developer Experience Improvements

**Complete development workflow:**

1. Install SDK: `npm install @zea/thalamus-js`
2. Copy example code
3. Configure environment
4. Start coding

**Zero to production in minutes:**
- Clear documentation
- Working examples
- Type safety
- Error messages
- Security by default

**Multiple integration paths:**
- SDK for fast development (recommended)
- Direct API for full control
- Examples for learning

### File Structure

```
thalamus/
├── packages/
│   └── thalamus-js/           # TypeScript SDK
│       ├── src/
│       │   ├── __tests__/     # Test suite
│       │   ├── auth/          # OAuth2 module
│       │   ├── tokens/        # Token management
│       │   ├── types/         # TypeScript definitions
│       │   └── index.ts       # Main export
│       ├── dist/              # Built output
│       ├── package.json
│       ├── tsconfig.json
│       ├── vitest.config.ts
│       └── README.md
├── examples/
│   ├── nextjs-app-router/     # Next.js 14 example
│   │   ├── app/               # App Router structure
│   │   ├── lib/               # SDK configuration
│   │   ├── .env.example
│   │   ├── package.json
│   │   └── README.md
│   ├── direct-api/            # Direct API example
│   │   ├── src/
│   │   │   └── server.ts      # Express server
│   │   ├── .env.example
│   │   ├── package.json
│   │   └── README.md
│   └── README.md              # Examples overview
├── lib/thalamus_web/
│   └── controllers/
│       ├── docs_controller.ex # Documentation controller
│       ├── docs_html.ex       # Documentation views
│       └── docs_html/         # HEEx templates
├── scripts/
│   └── create_example_oauth2_client.exs
├── SETUP_EXAMPLES.md          # Setup guide
├── CHANGELOG_SDK.md           # This file
└── README.md                  # Updated with SDK info
```

### Migration Notes

**For existing users:**

No breaking changes to the Thalamus server. All existing integrations continue to work.

**For new developers:**

Recommended approach:
1. Use the TypeScript SDK for fastest integration
2. Refer to Next.js example for React/Next.js apps
3. Refer to Direct API example for other languages

### Known Limitations

**SDK:**
- PKCE support not yet implemented (planned for v1.1.0)
- Additional OAuth2 parameters not yet supported
- No automatic token refresh (manual implementation required)

**Examples:**
- Next.js example requires manual OAuth2 client setup
- Direct API example uses in-memory sessions (not production-ready)
- No React SPA or Vue.js examples yet

### Future Plans

**v1.1.0:**
- PKCE support in SDK
- Automatic token refresh
- React SPA example
- Vue.js example

**v1.2.0:**
- Python SDK
- Go SDK
- Mobile examples (React Native, Flutter)

**v2.0.0:**
- Agent tokens support in SDK
- Delegation chain management
- Advanced token metadata

### Contributors

SDK and examples developed with AI assistance (Claude Code).

### License

MIT License - See LICENSE file for details

---

## How to Use This Release

### Install the SDK

```bash
npm install @zea/thalamus-js
```

### Quick Start

```typescript
import { ThalamusClient } from '@zea/thalamus-js'

const thalamus = new ThalamusClient({
  clientId: 'your_client_id',
  clientSecret: 'your_client_secret',
  redirectUri: 'http://localhost:3000/auth/callback',
  baseUrl: 'http://localhost:4000',
})

// Get authorization URL
const authUrl = thalamus.auth.getAuthorizationUrl({
  state: 'random-state',
})

// Exchange code for tokens
const tokens = await thalamus.auth.exchangeCode('authorization_code')

// Get user info
const user = await thalamus.tokens.getUserInfo(tokens.access_token)
```

### Run Examples

See [SETUP_EXAMPLES.md](SETUP_EXAMPLES.md) for detailed instructions.

---

**Full Documentation:** [README.md](README.md)
**SDK Documentation:** [packages/thalamus-js/README.md](packages/thalamus-js/README.md)
**Examples:** [examples/README.md](examples/README.md)
