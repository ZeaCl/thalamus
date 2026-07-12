# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ZEA Thalamus** is a production-ready OAuth2 authentication and authorization service built with Elixir 1.19+ and Phoenix 1.8. The project follows Clean Architecture with strict SOLID principles and is designed as the central authentication service for the ZEA ecosystem.

**Status**: Production-Ready (85% complete, v1.0.0-rc1)

Core features implemented:
- OAuth2 2.0 (Authorization Code, Client Credentials, Refresh Token grants)
- PKCE support (RFC 7636)
- Token introspection (RFC 7662) and revocation (RFC 7009)
- OpenID Connect userinfo endpoint
- Multi-factor authentication (TOTP)
- Multi-tenancy with organization management
- Role-based access control (RBAC)
- Comprehensive security features (rate limiting, CORS, security headers)

## Essential Commands

### Development Setup
```bash
# Initial setup (install deps, create DB, run migrations)
make setup
# or manually:
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# Start development server
make dev
# or:
mix phx.server

# Start with IEx shell
iex -S mix phx.server
```

### Testing
```bash
# Run all tests (automatically creates test DB and runs migrations)
mix test

# Run specific test suites
make test-domain              # Domain layer tests only
make test-controllers         # Controller tests only
make test-integration         # Integration tests only

# Run single test file
mix test test/path/to/file_test.exs

# Run single test by line number
mix test test/path/to/file_test.exs:42

# Run with coverage
make test-coverage

# Run failed tests only
mix test --failed
```

### Database Management
```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Seed database
mix run priv/repo/seeds.exs

# Check migration status
mix ecto.migrations
```

### Code Quality
```bash
# Format code
mix format

# Run linter (Credo)
mix credo --strict

# Static type analysis
mix dialyzer

# Run all quality checks
make check

# Pre-commit checks (compile with warnings as errors, format, test)
mix precommit
```

### Docker
```bash
# Start all services (PostgreSQL, Redis, application)
docker-compose up -d

# View logs
docker-compose logs -f thalamus

# Stop all services
docker-compose down

# PostgreSQL shell
docker-compose exec postgres psql -U postgres -d thalamus_dev

# Redis CLI
docker-compose exec redis redis-cli -a redis_password
```

## Architecture

### Clean Architecture Layers

The codebase strictly follows Clean Architecture with dependency inversion. Dependencies flow inward (outer layers depend on inner layers, never the reverse):

```
┌─────────────────────────────────────────────────────────────┐
│  Presentation Layer (lib/thalamus_web/)                     │
│  • Controllers (OAuth2, API, Session)                       │
│  • Plugs (CORS, SecurityHeaders, RateLimiter, AuthToken)   │
│  • Router                                                    │
│  • HTML templates                                           │
└──────────────────────┬──────────────────────────────────────┘
                       │ depends on ↓
┌──────────────────────▼──────────────────────────────────────┐
│  Application Layer (lib/thalamus/application/)              │
│  • Use Cases (AuthenticateUser, GenerateTokens, etc.)      │
│  • DTOs (AuthenticationRequest, TokenResponse, etc.)        │
│  • Ports/Interfaces (UserRepository, TokenRepository)      │
└──────────────────────┬──────────────────────────────────────┘
                       │ depends on ↓
┌──────────────────────▼──────────────────────────────────────┐
│  Domain Layer (lib/thalamus/domain/)                        │
│  • Entities (User, Organization, OAuth2Client)             │
│  • Value Objects (UserId, Email, AccessToken, etc.)        │
│  • Domain Services (pure business logic)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ implemented by ↑
┌──────────────────────▼──────────────────────────────────────┐
│  Infrastructure Layer (lib/thalamus/infrastructure/)        │
│  • Repositories (PostgresqlUserRepository, etc.)            │
│  • Persistence (Ecto schemas)                               │
│  • Adapters (cache, email, external services)              │
└─────────────────────────────────────────────────────────────┘
```

**Critical Rule**: Inner layers (Domain, Application) NEVER import from outer layers (Infrastructure, Web). Use ports (behaviours) for dependency inversion.

### Domain Layer (`lib/thalamus/domain/`)

Pure business logic with zero external dependencies:

**Entities** (`entities/`):
- `User` - User account with authentication state
- `Organization` - Multi-tenant organization entity
- `OAuth2Client` - Registered OAuth2 client applications

**Value Objects** (`value_objects/`):
- Must validate on creation (return `{:ok, value}` or `{:error, reason}`)
- Must be immutable
- Must implement `String.Chars` and `Jason.Encoder` protocols
- Examples: `UserId`, `Email`, `PasswordHash`, `AccessToken`, `RefreshToken`, `AuthorizationCode`

**Domain Services** (`services/`):
- Complex business logic spanning multiple entities
- Pure functions with no side effects

### Application Layer (`lib/thalamus/application/`)

Orchestrates business workflows using domain entities and infrastructure ports:

**Use Cases** (`use_cases/`):
- `AuthenticateUser` - Handles user login with password and MFA
- `GenerateTokens` - Creates OAuth2 access/refresh tokens
- `ValidateToken` - Validates and introspects tokens
- Each use case has a single `execute/2` function: `execute(request, deps)`
- Dependencies injected via `deps` map containing port implementations

**Ports** (`ports/`):
- Behaviour definitions (interfaces) for external dependencies
- `UserRepository` - User persistence interface
- `TokenRepository` - Token storage interface
- `OAuth2ClientRepository` - Client application interface
- `OrganizationRepository` - Organization persistence interface
- `AuditLogger` - Security event logging interface
- `EmailService` - Email sending interface
- `CacheService` - Caching interface

**DTOs** (`dtos/`):
- Data Transfer Objects for use case inputs and outputs
- Bridge between web layer and application layer

### Infrastructure Layer (`lib/thalamus/infrastructure/`)

Implements application layer ports with concrete technologies:

**Repositories** (`repositories/`):
- `PostgresqlUserRepository` - Implements UserRepository port
- `PostgresqlTokenRepository` - Implements TokenRepository port
- `PostgresqlOAuth2ClientRepository` - Implements OAuth2ClientRepository port
- `PostgresqlOrganizationRepository` - Implements OrganizationRepository port

**Persistence** (`persistence/`):
- Ecto schemas (database mappings)
- Database migrations in `priv/repo/migrations/`

**Adapters** (`adapters/`):
- Cache adapters (Cachex, Redis)
- Email service adapters
- External API adapters

### Presentation Layer (`lib/thalamus_web/`)

Phoenix web interface:

**Router** (`router.ex`):
- Pipeline definitions (`:browser`, `:api`, `:oauth2_browser`, `:oauth2_api`, `:authenticated_api`)
- OAuth2 endpoints: `/oauth/authorize`, `/oauth/token`, `/oauth/introspect`, `/oauth/revoke`, `/oauth/userinfo`
- Public API: `/api/public/*` (registration, password reset, health check)
- Authenticated API: `/api/*` (users, organizations, clients, MFA)

**Controllers**:
- `oauth2/` - OAuth2 authorization, token, introspection, revocation controllers
- `api/` - REST API controllers for user/organization/client management
- Session management for login/logout

**Plugs**:
- `CORS` - Cross-origin resource sharing
- `SecurityHeaders` - Security headers (CSP, HSTS, etc.)
- `RateLimiter` - Rate limiting per IP/user
- `AuthenticateToken` - Bearer token authentication

## SOLID Principles (Strictly Enforced)

1. **Single Responsibility**: Each module has one reason to change
   - Value Objects only validate and format data
   - Use Cases handle one business workflow
   - Repositories handle one entity's persistence

2. **Open/Closed**: Extend without modifying
   - Use protocols for polymorphic behavior
   - Add new use cases without changing existing ones
   - Add new repositories without changing ports

3. **Liskov Substitution**: Implementations honor contracts
   - All repository implementations must satisfy port behaviour
   - Protocol implementations must work interchangeably

4. **Interface Segregation**: Small, focused interfaces
   - Separate repository port per entity
   - Separate service ports by concern
   - No "god interfaces"

5. **Dependency Inversion**: Depend on abstractions
   - Application layer defines ports (behaviours)
   - Infrastructure layer implements ports
   - Controllers depend on use cases, not repositories

## Coding Standards

### Error Handling Pattern

Always use tagged tuples for results:

```elixir
def operation(input) do
  with {:ok, validated} <- validate(input),
       {:ok, processed} <- process(validated) do
    {:ok, processed}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### Value Object Pattern

```elixir
defmodule Thalamus.Domain.ValueObjects.Example do
  @moduledoc """
  Value Object for X.

  SOLID Principles Applied:
  - Single Responsibility: Only validates X
  - Open/Closed: Extensible via protocols
  """

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  def new(value) do
    case validate(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate(value) do
    # Validation logic
    :ok
  end
end

# Protocol implementations (REQUIRED)
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Example do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Example do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end
```

### Use Case Pattern

```elixir
defmodule Thalamus.Application.UseCases.ExampleUseCase do
  @moduledoc """
  Use case for X.

  SOLID Principles:
  - Single Responsibility: Only handles X workflow
  - Dependency Inversion: Depends on ports, not implementations
  """

  alias Thalamus.Application.Ports.ExampleRepository
  alias Thalamus.Domain.Entities.Example

  @type deps :: %{
    example_repository: module(),
    audit_logger: module()
  }

  def execute(request, %{example_repository: repo} = deps) do
    with {:ok, entity} <- Example.create(request),
         {:ok, saved} <- repo.save(entity) do
      {:ok, saved}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Repository Implementation Pattern

```elixir
defmodule Thalamus.Infrastructure.Repositories.PostgresqlExampleRepository do
  @moduledoc """
  PostgreSQL implementation of ExampleRepository port.
  """

  @behaviour Thalamus.Application.Ports.ExampleRepository

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.ExampleSchema

  @impl true
  def find_by_id(id) do
    case Repo.get(ExampleSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def save(entity) do
    changeset = to_changeset(entity)
    case Repo.insert_or_update(changeset) do
      {:ok, schema} -> {:ok, to_domain(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp to_domain(schema) do
    # Map Ecto schema to domain entity
  end

  defp to_changeset(entity) do
    # Map domain entity to Ecto changeset
  end
end
```

## Security Requirements

### Cryptographic Operations

**Token Generation** - Always use cryptographically secure random:
```elixir
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
```

**Constant-Time Comparison** - Prevent timing attacks:
```elixir
Plug.Crypto.secure_compare(token1, token2)
```

**Password Hashing** - Use Bcrypt (already configured):
```elixir
Bcrypt.hash_pwd_salt(password, rounds: 10)
Bcrypt.verify_pass(password, hash)
```

### Input Validation

Always validate:
- Length constraints (min/max)
- Character set (alphanumeric, special chars)
- Format (email, URL, UUID)
- Business rules (domain-specific constraints)

Validation happens in Value Objects for reusability.

### Rate Limiting

Rate limits configured in router pipelines:
- Public API: 1000 req/min per IP
- OAuth2 endpoints: 100 req/min per IP
- Authorization endpoint: 20 req/min per IP
- Authenticated API: 5000 req/min per user

## OAuth2 Implementation

### Grant Types Supported

1. **Authorization Code Grant** (RFC 6749 Section 4.1)
   - PKCE required (code_challenge, code_verifier)
   - Flow: `/oauth/authorize` → `/oauth/token`

2. **Client Credentials Grant** (RFC 6749 Section 4.4)
   - For machine-to-machine authentication
   - Flow: `/oauth/token` with `grant_type=client_credentials`

3. **Refresh Token Grant** (RFC 6749 Section 6)
   - Token rotation enabled (new refresh token issued)
   - Flow: `/oauth/token` with `grant_type=refresh_token`

### Endpoints

- `GET /oauth/authorize` - Authorization page (user consent)
- `POST /oauth/authorize` - Process authorization (returns code)
- `POST /oauth/token` - Exchange code/credentials for tokens (all grant types)
- `POST /oauth/agent-token` - Agent-specific tokens with task-scoping
- `GET /oauth/userinfo` - OpenID Connect user info endpoint
- `POST /oauth/introspect` - Token introspection (RFC 7662)
- `POST /oauth/revoke` - Token revocation (RFC 7009)
- `GET /.well-known/openid-configuration` - OIDC Discovery
- `GET /.well-known/jwks.json` - JWKS public keys for JWT verification

### Scopes

**Standard OIDC**: `openid`, `profile`, `email`, `address`, `phone`, `offline_access`

**ZEA Platform**: `zea:read`, `zea:write`, `zea:admin`, `synapse:events`, `cortex:chat`, `billing:read`, `organizations:write`

**Custom configurable** via `config :thalamus, :oauth2_scopes`

### Agent Tokens

Agent tokens extend OAuth2 with task-scoping, delegation chains (max depth 4), and compliance-ready audit trails.

- **Agent types**: `autonomous`, `supervisor`, `tool`
- **Delegation**: human → agent → sub-agent chains
- **Step authorization**: `POST /api/authorization/validate-step` called by Cerebelum before each workflow step
- **Feature flag**: Gated behind `agent_tokens_enabled`
- See [docs/agents/](docs/agents/) for full documentation

## Testing Strategy

### Test Organization

```
test/
├── thalamus/
│   ├── domain/              # Pure unit tests (no mocks, fast)
│   │   ├── entities/
│   │   └── value_objects/
│   ├── application/         # Use case tests (with Mox)
│   │   └── use_cases/
│   └── infrastructure/      # Integration tests (with DB)
│       └── repositories/
└── thalamus_web/
    └── controllers/         # Controller tests (with DB)
```

### Testing Standards

**Domain Layer Tests** - Pure unit tests:
- No database, no mocks
- Test business logic directly
- Fast execution

**Application Layer Tests** - Use case tests:
- Use Mox to mock ports (repositories, services)
- Test workflow orchestration
- Verify port interactions

**Infrastructure Tests** - Integration tests:
- Use real database with Ecto.Adapters.SQL.Sandbox
- Test actual database operations
- Test external service integrations

**Controller Tests** - HTTP integration tests:
- Use ConnTest helpers
- Test request/response handling
- Test authentication/authorization

### Test Setup

```elixir
# Domain tests - no setup needed
defmodule Thalamus.Domain.Entities.UserTest do
  use ExUnit.Case, async: true
  # Pure business logic tests
end

# Application tests - with mocks
defmodule Thalamus.Application.UseCases.AuthenticateUserTest do
  use ExUnit.Case, async: true
  import Mox
  # Mock port behaviours
  setup :verify_on_exit!
end

# Infrastructure tests - with database
defmodule Thalamus.Infrastructure.Repositories.PostgresqlUserRepositoryTest do
  use Thalamus.DataCase, async: true
  # Database tests with sandbox
end

# Controller tests - with database and HTTP
defmodule ThalamusWeb.API.UserControllerTest do
  use ThalamusWeb.ConnCase, async: true
  # HTTP integration tests
end
```

## Phoenix 1.8 Specifics

### LiveView/HEEx Templates

- Use `~H` sigil or `.html.heex` files
- Attribute interpolation: `<div id={@id} class={@class}>`
- Block constructs: `<%= if @condition do %> ... <% end %>`
- Use `cond` for multiple conditions (Elixir has no `elsif`)
- Heroicons: `<.icon name="hero-x-mark">` (imported in core_components)
- Comments: `<%!-- comment --%>`

### Forms

Use Phoenix.Component form helpers:
```heex
<.form :let={f} for={@changeset} action={~p"/users"}>
  <.input field={f[:email]} type="email" label="Email" />
  <.input field={f[:password]} type="password" label="Password" />
  <:actions>
    <.button>Submit</.button>
  </:actions>
</.form>
```

### Navigation

Use function-verified routes:
```elixir
# In templates
~p"/users/#{@user}"

# In controllers
redirect(conn, to: ~p"/login")
```

### Ecto Guidelines

- Always preload associations before accessing in templates
- Schema fields use `:string` type even for TEXT columns
- Use `Ecto.Changeset.get_field/2` to access changeset fields
- Fields set programmatically (like `user_id`) must NOT be in `cast/3`

## Environment Configuration

### Development

```bash
# Database
DATABASE_URL=ecto://dev@localhost/thalamus_dev
DB_POOL_SIZE=10

# Server
PHX_HOST=localhost
PORT=4000

# Security (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your-secret-key-base-min-64-chars
```

### Test

Test environment uses in-memory configuration. Database is created/migrated automatically when running tests.

### Production

Set these environment variables in production:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Cryptographic key base (64+ chars)
- `PHX_HOST` - Production hostname
- `PORT` - HTTP port (default: 4000)

## Dependencies

Key libraries used:

**Authentication/Security**:
- `guardian` (~> 2.3) - JWT token management
- `joken` (~> 2.6) - JWT signing and verification
- `bcrypt_elixir` (~> 3.0) - Password hashing
- `pot` (~> 1.0) - TOTP for MFA

**Database/Persistence**:
- `ecto_sql` (~> 3.13) - Database wrapper
- `postgrex` - PostgreSQL driver

**Caching/Performance**:
- `cachex` (~> 3.6) - In-memory cache
- `redix` (~> 1.2) - Redis client

**Background Jobs**:
- `oban` (~> 2.17) - Job queue

**Rate Limiting**:
- `hammer` (~> 6.2) - Rate limiter

**HTTP**:
- `req` (~> 0.4) - Modern HTTP client (use this, not HTTPoison)

**Testing**:
- `mox` (~> 1.1) - Mocks and stubs
- `ex_machina` (~> 2.7) - Test factories

## Project Structure Reference

```
lib/
├── thalamus/
│   ├── application.ex                    # OTP application entry point
│   ├── repo.ex                          # Ecto repo
│   ├── domain/
│   │   ├── entities/                    # Business entities (User, Organization, OAuth2Client)
│   │   ├── value_objects/               # Validated immutable values
│   │   ├── repositories/                # Repository interfaces (unused, defined in ports)
│   │   └── services/                    # Domain services
│   ├── application/
│   │   ├── use_cases/                   # Business workflows (AuthenticateUser, GenerateTokens)
│   │   ├── ports/                       # Interfaces for infrastructure (behaviours)
│   │   └── dtos/                        # Data transfer objects
│   └── infrastructure/
│       ├── repositories/                # Repository implementations (PostgreSQL)
│       ├── persistence/                 # Ecto schemas
│       │   └── schemas/
│       ├── adapters/                    # External service adapters
│       └── external/                    # External API clients
├── thalamus_web/
│   ├── controllers/
│   │   ├── oauth2/                      # OAuth2 endpoints
│   │   ├── api/                         # REST API endpoints
│   │   └── session_controller.ex       # Login/logout
│   ├── plugs/                           # Custom plugs (CORS, auth, rate limiting)
│   ├── components/                      # Reusable UI components
│   ├── router.ex                        # Route definitions
│   ├── endpoint.ex                      # Phoenix endpoint
│   └── telemetry.ex                     # Metrics and monitoring
├── thalamus_web.ex                      # Web module definitions
└── thalamus.ex                          # Base module definitions

priv/
├── repo/
│   ├── migrations/                      # Database migrations
│   └── seeds.exs                        # Database seeds
└── static/                              # Static assets

config/
├── config.exs                           # Base configuration
├── dev.exs                              # Development config
├── test.exs                             # Test config
├── prod.exs                             # Production config
└── runtime.exs                          # Runtime configuration

test/
├── support/                             # Test helpers
│   ├── conn_case.ex                     # Controller test helpers
│   ├── data_case.ex                     # Repository test helpers
│   └── fixtures.ex                      # Test data fixtures
├── thalamus/                            # Application tests
│   ├── domain/
│   ├── application/
│   └── infrastructure/
└── thalamus_web/                        # Web tests
    └── controllers/
```

## Quality Standards

Before committing code:

1. **All tests pass**: `mix test`
2. **Code formatted**: `mix format`
3. **No linter warnings**: `mix credo --strict`
4. **Documentation complete**: All public functions have `@doc`

Run pre-commit checks:
```bash
mix precommit
```

This runs: compile (warnings as errors), format check, and full test suite.

## Common Patterns

### Adding a New Entity

1. Create value objects in `lib/thalamus/domain/value_objects/`
2. Create entity in `lib/thalamus/domain/entities/`
3. Create repository port in `lib/thalamus/application/ports/`
4. Create Ecto schema in `lib/thalamus/infrastructure/persistence/schemas/`
5. Create repository implementation in `lib/thalamus/infrastructure/repositories/`
6. Create migration in `priv/repo/migrations/`
7. Write tests for each layer
8. Document the feature in `docs/api/` or `docs/oauth2/`

### Adding a New Use Case

1. Create DTO in `lib/thalamus/application/dtos/`
2. Create use case in `lib/thalamus/application/use_cases/`
3. Inject dependencies via `deps` parameter
4. Use existing ports or create new ones
5. Write tests with Mox for port mocking

### Adding a New API Endpoint

1. Add route in `lib/thalamus_web/router.ex`
2. Create controller in `lib/thalamus_web/controllers/`
3. Call use case from controller
4. Return proper HTTP status codes
5. Write controller tests with database fixtures
6. Document the endpoint in `docs/api/` with parameter tables + curl examples + error codes

### Adding Documentation

Follow the cerebelum-core pattern:
1. Read the controller/ex code first — validate everything against real code
2. Write the doc file in the appropriate `docs/` section
3. Use the format: parameter table → curl example → response → error codes → code snippets
4. Cross-link to related docs
5. Update `docs/index.md` if adding a new top-level file
6. Never reference files that don't exist

## Resources

- **[docs/index.md](docs/index.md)** — Documentation hub (5 personas: dev, agente, devops, admin, arquitecto)
- **[docs/getting-started.md](docs/getting-started.md)** — Quickstart por caso de uso
- **[docs/oauth2/](docs/oauth2/)** — OAuth2 reference (8 archivos: overview, authorization-code, client-credentials, token-introspection, token-revocation, userinfo, discovery, agent-tokens)
- **[docs/agents/](docs/agents/)** — Agent docs (overview, CLI reference, skills catalog)
- **[docs/api/](docs/api/)** — REST API reference (11 archivos: rest, authentication, users, organizations, clients, roles, mfa, secrets, domains, personal-access-tokens, audit-logs)
- **[docs/architecture/overview.md](docs/architecture/overview.md)** — Clean Architecture, capas, entidades, puertos
- **[docs/configuration.md](docs/configuration.md)** — Email, planes, scopes, feature flags, env vars
- **[docs/deployment.md](docs/deployment.md)** — Docker, producción, reverse proxy
- **[docs/guides/](docs/guides/)** — Guías prácticas (admin-api-keys, saml-sso, oauth2-client-management, dashboard)
- **[docs/OPENAPI_SPEC.yaml](docs/OPENAPI_SPEC.yaml)** — OpenAPI 3.0 specification
- **[docs/tutorials/](docs/tutorials/)** — Tutoriales paso a paso para integradores

### Documentation conventions

- Every doc file is validated against real code in `lib/`
- No broken links — `index.md` only references files that exist
- Each doc follows cereal pattern: parameter tables → curl examples → response format → error codes → code snippets
- Persona-first: docs route readers by role (dev integrating, AI agent, devops on-prem, admin, architect)

---

## Memoria operativa (`.wiki/`)

El agente mantiene un wiki de conocimiento operativo en `.wiki/`. Es **la memoria del equipo interno entre sesiones** — permite saber qué se hizo, cómo funcionan las integraciones, y qué patrones se descubrieron sin tener que re-explorar cada vez.

> ⚠️ Esto NO es documentación para desarrolladores externos ni agentes que integran Thalamus (eso está en `docs/`). Esto es para el equipo que mantiene y opera Thalamus.

### Estructura

```
.wiki/
  index.md              ← catálogo de todas las páginas (el agente lo mantiene)
  log.md                ← bitácora cronológica (qué se hizo y cuándo)
  rules.md              ← convenciones y patrones descubiertos (evoluciona este CLAUDE.md)
  features/
    <feature>.md        ← una página por feature/bug (estado, decisiones, gotchas)
  integrations/
    <servicio>.md       ← una página por servicio/infra (endpoints, auth, quirks)
```

### Cuándo escribir

| Momento | Acción |
|---|---|
| Al **terminar una feature o fix** (merge a main) | Crear/actualizar `.wiki/features/<feature>.md` con: qué se hizo, decisiones clave, archivos modificados, errores encontrados y cómo se resolvieron |
| Al **descubrir un patrón o regla** | Agregar a `.wiki/rules.md` y actualizar este CLAUDE.md si corresponde |
| Al **aprender algo nuevo sobre una integración** | Crear/actualizar `.wiki/integrations/<servicio>.md` con: conexión, auth, formato de datos, limitaciones, ejemplos |
| **Siempre**, después de cualquier cambio significativo | Agregar entrada a `.wiki/log.md` con formato: `## [YYYY-MM-DD] <tipo> \| <descripción breve>` |
| **Siempre** | Mantener `.wiki/index.md` actualizado con links y one-liners de cada página |

### Cuándo leer

| Momento | Qué leer |
|---|---|
| Al **iniciar una sesión nueva** | `.wiki/log.md` (últimas entradas) + `.wiki/index.md` |
| Antes de **tocar una integración** | `.wiki/integrations/<servicio>.md` |
| Antes de **empezar una feature** | `.wiki/features/<feature>.md` (si existe) + `.wiki/rules.md` |
| Al **encontrar un error** | `.wiki/log.md` + `.wiki/features/` relacionadas (por si ya se resolvió antes) |

### Formato de feature page

```markdown
# <Feature Name>

- **Issue**: #N
- **Rama**: feature/<nombre>
- **Estado**: ✅ merged / 🔄 en progreso / ⬜ planeado

## Qué se hizo
[2-3 bullets]

## Decisiones clave
- [decisión 1]
- [decisión 2]

## Archivos modificados
- `lib/...`

## Errores encontrados
- [error] → [solución]

## Referencias
- [links a PR, issues, docs]
```

### Formato de integration page

```markdown
# <Servicio>

- **URL**: http://...
- **Auth**: Bearer token / API key / etc
- **Repositorio**: /path/to/repo

## Conexión
[comandos para conectar, health check]

## Endpoints / Tablas / Schemas
[tabla con lo relevante]

## Formato de datos
[ejemplo de request/response o schema]

## Limitaciones / Quirks
- [cosa rara que hace el servicio]
```

### Reglas de mantenimiento

- El agente **SIEMPRE** actualiza el wiki después de un cambio significativo. No espera a que se lo pidan.
- Las páginas son markdown plano. Nada de frontmatter complejo.
- Si una página tiene más de ~50 líneas, considerar splitearla.
- El `log.md` usa el prefijo `## [YYYY-MM-DD]` para que sea parseable con grep.
- El wiki se commitea junto con el código. Es parte del repo.
