# ZEA Thalamus 🔐

**Enterprise-Grade OAuth2 Authentication & Authorization Service**

[![Elixir](https://img.shields.io/badge/elixir-1.17-purple.svg)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/phoenix-1.7-orange.svg)](https://phoenixframework.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](#testing)

ZEA Thalamus is a production-ready OAuth2 server built with **Clean Architecture** and **SOLID principles**. It provides complete OAuth2 2.0 implementation with advanced security features, multi-tenancy support, and comprehensive REST API.

---

## 🎯 Features

### Core OAuth2 (RFC Compliant)
- ✅ **Authorization Code Grant** (RFC 6749)
- ✅ **Client Credentials Grant** (RFC 6749)
- ✅ **Refresh Token Grant** (RFC 6749)
- ✅ **PKCE Support** (RFC 7636)
- ✅ **Token Introspection** (RFC 7662)
- ✅ **Token Revocation** (RFC 7009)

### Security & Authentication
- 🔒 **Multi-Factor Authentication** (TOTP)
- 🔒 **Backup Codes** for account recovery
- 🔒 **Email Verification** with secure tokens
- 🔒 **Password Reset** with anti-enumeration
- 🔒 **Admin API Keys** for service-to-service authentication
- 🔒 **Rate Limiting** (per IP, user, client)
- 🔒 **CORS Configuration** with origin whitelisting
- 🔒 **Security Headers** (CSP, HSTS, X-Frame-Options)
- 🔒 **Audit Logging** for all security events

### Enterprise Features
- 🏢 **Multi-Tenancy** with organization management
- 🏢 **Role-Based Access Control** (RBAC)
- 🏢 **User Management** API
- 🏢 **Client Application** management
- 🏢 **Flexible Plans** (Free, Starter, Professional, Enterprise)

### Developer Experience
- 📚 **OpenAPI 3.0 Documentation** (Swagger)
- 🐳 **Docker & Docker Compose** ready
- 🔧 **Makefile** with common commands
- 🧪 **Comprehensive Test Suite** (10/10 controllers tested)
- 📖 **Complete Documentation**

---

## 📊 Project Status

**Version:** 1.0.0-rc1
**Status:** Production-Ready (Core Features)
**Completion:** 87%

### Implementation Status
- ✅ Domain Layer: 100%
- ✅ Application Layer: 100%
- ✅ Infrastructure Layer: 100%
- ✅ Presentation Layer: 97%
- ✅ Security: 100%
- ✅ Admin API Keys: 100% (NEW)
- ⚠️  Testing: 75% (all core features tested)
- ⚠️  Documentation: 85%

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for detailed status.

---

## 🚀 Quick Start

### Prerequisites

- **Elixir** 1.17+ and **Erlang** 26+
- **PostgreSQL** 16+
- **Redis** 7+ (optional, for rate limiting)
- **Docker** & **Docker Compose** (optional)

### Option 1: Docker (Recommended)

```bash
# Clone repository
git clone <repository_url>
cd thalamus

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f thalamus

# Access application
open http://localhost:4000
```

**Services:**
- **Application:** http://localhost:4000
- **Adminer (DB UI):** http://localhost:8080
- **Redis Commander:** http://localhost:8081

### Option 2: Local Development

```bash
# Install dependencies
make setup

# Or manually:
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# Start server
make dev
# Or: mix phx.server

# Visit
open http://localhost:4000
```

---

## 🔧 Configuration

### Environment Variables

Create `.env` file (copy from `.env.example`):

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost:5432/thalamus_dev
DB_POOL_SIZE=10

# Redis
REDIS_URL=redis://:redis_password@localhost:6379/0

# Security
SECRET_KEY_BASE=your-secret-key-base-min-64-chars
VERIFICATION_TOKEN_SECRET=your-verification-token-secret
PASSWORD_RESET_SECRET=your-password-reset-secret
SESSION_SECRET=your-session-secret

# Email
EMAIL_MODE=development
EMAIL_FROM=noreply@localhost
EMAIL_BASE_URL=http://localhost:4000

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:4000
```

### Generate Secrets

```bash
# Generate random secret (64 characters)
mix phx.gen.secret

# Or use OpenSSL
openssl rand -base64 64
```

---

## 📚 API Documentation

### Authentication Methods

Thalamus supports two authentication methods:

#### 1. JWT Bearer Token (User Authentication)
For user-facing operations:
```bash
curl -H "Authorization: Bearer <jwt_token>" \
  http://localhost:4000/api/users
```

#### 2. Admin API Keys (Service-to-Service)
For automated operations and service integrations:
```bash
curl -H "Authorization: ApiKey ak_dev_..." \
  http://localhost:4000/api/admin/api-keys
```

**Note:** Admin API Keys can only be created by super admin users and are intended for service-to-service authentication (e.g., allowing external systems to register OAuth2 clients programmatically).

### Endpoints

#### OAuth2 Endpoints
```
GET  /oauth/authorize         - Authorization screen
POST /oauth/authorize         - Process consent
POST /oauth/token             - Exchange code for tokens
POST /oauth/introspect        - Validate tokens
POST /oauth/revoke            - Revoke tokens
```

#### Public Endpoints
```
GET  /api/public/health                - Health check
POST /api/public/register              - User registration
POST /api/public/verify-email          - Email verification
POST /api/public/password/reset        - Request password reset
POST /api/public/password/confirm-reset - Confirm password reset
```

#### Authenticated Endpoints (Require Bearer Token)
```
# Users
GET    /api/users
POST   /api/users
GET    /api/users/:id
PATCH  /api/users/:id
DELETE /api/users/:id

# Organizations
GET    /api/organizations
POST   /api/organizations
GET    /api/organizations/:id
PATCH  /api/organizations/:id
DELETE /api/organizations/:id

# OAuth2 Clients
GET    /api/clients
POST   /api/clients
GET    /api/clients/:id
PATCH  /api/clients/:id
DELETE /api/clients/:id

# Multi-Factor Authentication
POST   /api/mfa/totp/setup              - Setup TOTP
POST   /api/mfa/totp/verify             - Verify & enable MFA
DELETE /api/mfa/disable                 - Disable MFA
POST   /api/mfa/backup-codes/regenerate - Regenerate backup codes

# Admin API Keys (Super Admin Only)
GET    /api/admin/api-keys              - List all API keys
POST   /api/admin/api-keys              - Create new API key
GET    /api/admin/api-keys/:id          - Get specific API key
DELETE /api/admin/api-keys/:id          - Revoke API key
POST   /api/admin/api-keys/:id/rotate   - Rotate API key secret
```

### OpenAPI/Swagger

Full API documentation available in [OPENAPI_SPEC.yaml](OPENAPI_SPEC.yaml)

View with Swagger UI:
```bash
# Using Docker
docker run -p 8082:8080 -e SWAGGER_JSON=/spec/openapi.yaml \
  -v $(pwd)/OPENAPI_SPEC.yaml:/spec/openapi.yaml swaggerapi/swagger-ui
```

---

## 🧪 Testing

### Run All Tests

```bash
make test
# Or: mix test
```

### Run Specific Test Suites

```bash
make test-domain        # Domain tests
make test-controllers   # Controller tests
make test-integration   # Integration tests
make test-coverage      # With coverage report
```

### Test Coverage

Current coverage: **75%**
- Domain Layer: 100%
- Application Layer: 100%
- Infrastructure Layer: 95%
- Controllers: 100% (all critical paths)

---

## 🔑 Admin API Keys

Admin API Keys enable secure service-to-service authentication for automated operations. They are ideal for scenarios where external systems need to interact with Thalamus without user intervention.

### Use Cases

- **Automatic Client Registration:** External services can register as OAuth2 clients programmatically
- **Machine-to-Machine (M2M) Setup:** Backend services can self-register for M2M authentication
- **Service Integration:** Backend services can manage users, organizations, and clients
- **CI/CD Pipelines:** Automate testing and deployment workflows
- **Monitoring & Analytics:** Scheduled jobs can query system metrics

### Creating an API Key

Only super admin users can create Admin API Keys:

```bash
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sport Backend Integration",
    "description": "API Key for Sport app to register OAuth2 clients",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

Response:
```json
{
  "data": {
    "id": "uuid",
    "api_key": "ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL",
    "key_prefix": "ak_dev_vK8m",
    "name": "Sport Backend Integration",
    "scopes": ["clients:write", "clients:read"],
    "is_active": true,
    "expires_at": "2026-12-31T23:59:59Z"
  },
  "message": "⚠️ IMPORTANT: Save the api_key in a secure location. It cannot be retrieved later."
}
```

**⚠️ Security Warning:** The full API key is only shown once during creation. Store it securely (e.g., in environment variables or a secrets manager).

### Using an API Key

Authenticate using the `Authorization: ApiKey` header:

```bash
curl -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  http://localhost:4000/api/clients
```

### Available Scopes

- `clients:read` - View OAuth2 client applications
- `clients:write` - Create and update OAuth2 clients
- `clients:delete` - Delete OAuth2 clients
- `users:read` - View users
- `users:write` - Create and update users
- `organizations:read` - View organizations
- `organizations:write` - Create and update organizations
- `corpus:read` - Read corpus data
- `corpus:write` - Write corpus data

### Key Rotation

Rotate an API key to generate a new secret (invalidates the old one):

```bash
curl -X POST http://localhost:4000/api/admin/api-keys/{id}/rotate \
  -H "Authorization: Bearer <super_admin_jwt>"
```

### Security Features

- **Bcrypt Hashing:** Keys are hashed before storage (never stored in plaintext)
- **Prefix Lookup:** Only the key prefix is used for efficient lookups
- **Scoped Permissions:** Fine-grained access control via scopes
- **Expiration Support:** Optional expiration dates
- **Revocation:** Keys can be instantly revoked
- **Audit Logging:** All API key operations are logged
- **Last Used Tracking:** Monitor API key usage

### M2M (Machine-to-Machine) Setup with Admin API Keys

Admin API Keys enable fully automated M2M setup for backend services:

**Step 1: Super Admin creates Admin API Key** (one-time)

```bash
curl -X POST http://localhost:4000/api/admin/api-keys \
  -H "Authorization: Bearer <super_admin_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Campaigns Backend",
    "scopes": ["clients:write", "clients:read"],
    "expires_at": "2026-12-31T23:59:59Z"
  }'
```

**Step 2: Backend service auto-registers as M2M client**

```bash
# Using the Admin API Key from Step 1
curl -X POST http://localhost:4000/api/clients \
  -H "Authorization: ApiKey ak_dev_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8jL" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Campaigns Backend Service",
    "organization_id": "<org-uuid>",
    "client_type": "confidential",
    "redirect_uris": [],
    "grant_types": ["client_credentials"],
    "scopes": ["campaigns:read", "campaigns:write"]
  }'

# Response includes client_id and client_secret (save these!)
```

**Step 3: Backend service requests M2M tokens**

```bash
curl -X POST http://localhost:4000/oauth/token \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "<client_id>",
    "client_secret": "<client_secret>",
    "scope": "campaigns:read campaigns:write"
  }'

# Response: { "access_token": "...", "expires_in": 3600 }
```

**Step 4: Use access token for API calls**

```bash
curl -X GET http://localhost:4000/api/users \
  -H "Authorization: Bearer <access_token>"
```

See the **[Integration Guide](docs/INTEGRATION_GUIDE.md)** for complete examples in Python, Node.js, and more.

---

## 🏗️ Architecture

ZEA Thalamus follows **Clean Architecture** with strict layer separation:

```
┌─────────────────────────────────────────────────┐
│         Presentation Layer (Phoenix)            │
│  Controllers • Plugs • Router • Views           │
└────────────────┬────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────┐
│         Application Layer (Use Cases)           │
│  Business Logic • DTOs • Ports (Interfaces)     │
└────────────────┬────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────┐
│         Domain Layer (Pure Business Logic)      │
│  Entities • Value Objects • Domain Services     │
└─────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────┐
│         Infrastructure Layer (External)         │
│  Repositories • Adapters • Database • Cache     │
└─────────────────────────────────────────────────┘
```

### SOLID Principles Applied

- **S**ingle Responsibility: Each module has one reason to change
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes can replace parent types
- **I**nterface Segregation: Small, focused interfaces
- **D**ependency Inversion: Depend on abstractions, not concretions

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

---

## 🐳 Docker Deployment

### Development

```bash
docker-compose up -d
```

### Production

```bash
# Build production image
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build

# Start production services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 🔐 Security

### Rate Limiting
- Public API: 1,000 requests/minute per IP
- OAuth2 endpoints: 20 requests/minute per IP
- Authenticated API: 5,000 requests/minute per user

### Security Headers
- Content-Security-Policy (XSS protection)
- X-Frame-Options (clickjacking protection)
- Strict-Transport-Security (HSTS)
- X-Content-Type-Options (MIME sniffing protection)

### Data Protection
- Password hashing with Bcrypt (10 rounds)
- API key hashing with Bcrypt (never stored in plaintext)
- Constant-time password and key comparison
- Email verification required
- Account locking after 5 failed attempts
- HMAC-signed tokens with expiration
- Scoped permissions for API keys

---

## 📖 Documentation

**New to Thalamus?** 👉 **[Getting Started Guide](docs/GETTING_STARTED.md)** - 4-step integration guide

### For Users & Integrators

- **[Getting Started](docs/GETTING_STARTED.md)** - Quick integration guide (start here!)
- **[Documentation Index](docs/README.md)** - Complete documentation catalog
- **[Integration Guide](docs/INTEGRATION_GUIDE.md)** - Complete technical reference
- **[Admin API Keys](docs/guides/admin-api-keys.md)** - Service-to-service authentication
- **[API Specification](docs/OPENAPI_SPEC.yaml)** - OpenAPI 3.0 complete API documentation
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Production deployment instructions

### For Contributors

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to the project
- **[Architecture](docs/ARCHITECTURE.md)** - Clean Architecture & SOLID principles

---

## 🛠️ Development

### Useful Commands

```bash
make help            # Show all available commands
make setup           # Initial project setup
make dev             # Start development server
make test            # Run tests
make format          # Format code
make lint            # Run linter
make docker-up       # Start Docker services
make db-migrate      # Run migrations
make db-seed         # Seed database
```

### Code Quality

```bash
make check           # Run all quality checks
make dialyzer        # Static analysis
make security        # Security audit
```

---

## 📊 Monitoring

### Health Check

```bash
curl http://localhost:4000/api/public/health
```

Response:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2025-10-26T12:00:00Z",
  "checks": {
    "database": "ok",
    "cache": "ok"
  }
}
```

### Logs

```bash
# View application logs
docker-compose logs -f thalamus

# View all logs
docker-compose logs -f
```

---

## 📚 Documentation

Complete documentation is available in the [`docs/`](docs/) directory.

### 🚀 Quick Start

**New to Thalamus?** Start here:

👉 **[Getting Started Guide](docs/GETTING_STARTED.md)** - 4-step integration guide

### For Users & Integrators

- **[Getting Started](docs/GETTING_STARTED.md)** - Quick integration guide (start here!)
- **[Documentation Index](docs/README.md)** - Complete documentation catalog
- **[Integration Guide](docs/INTEGRATION_GUIDE.md)** - Complete technical reference
- **[API Specification](docs/OPENAPI_SPEC.yaml)** - OpenAPI 3.0 complete API documentation
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Production deployment instructions
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture and design decisions

### Specific Guides

- **[Admin API Keys](docs/guides/admin-api-keys.md)** - Service-to-service authentication
- More guides available in [docs/guides/](docs/guides/)

### For Contributors

- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Development setup, coding standards, and contribution workflow
- **[CLAUDE.md](CLAUDE.md)** - Instructions for AI-assisted development

### Internal Documentation

Development history and internal docs are available in [`docs/internal/`](docs/internal/)

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

For issues, questions, or contributions:
- **Issues:** GitHub Issues
- **Discussions:** GitHub Discussions

---

## 🙏 Acknowledgments

- Built with [Elixir](https://elixir-lang.org/) and [Phoenix Framework](https://phoenixframework.org/)
- Inspired by Clean Architecture principles
- OAuth2 RFCs: 6749, 7636, 7662, 7009

---

**Made with ❤️ using Clean Architecture and SOLID principles**
