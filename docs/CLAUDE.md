# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ZEA Thalamus** is an enterprise-grade OAuth2 authentication and authorization service built with Elixir/Phoenix. It follows Clean Architecture principles with SOLID design patterns and is designed to be the central authentication service for the ZEA ecosystem.

The project implements:
- OAuth2/OpenID Connect server
- Multi-factor authentication (TOTP, SMS, WebAuthn/FIDO2)
- Enterprise security (PCI-DSS, HIPAA, GDPR compliance)
- Token management with PKCE
- Fraud detection and rate limiting

## Essential Commands

### Development
```bash
# Setup project (install deps, create DB, run migrations, setup assets)
mix setup

# Start development server
mix phx.server

# Start server with IEx shell
iex -S mix phx.server

# Install/update dependencies
mix deps.get

# Reset database (drop, create, migrate, seed)
mix ecto.reset
```

### Testing
```bash
# Run all tests (creates test DB, runs migrations, then tests)
mix test

# Run unit tests only (no database setup)
mix test.unit

# Run integration tests (with database)
mix test.integration

# Run specific test file
mix test test/path/to/test_file.exs

# Run previously failed tests
mix test --failed

# Standalone unit test runner (for Value Objects, no database required)
elixir test_value_objects.exs
```

### Database
```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Run seeds
mix run priv/repo/seeds.exs
```

### Assets
```bash
# Install asset dependencies
mix assets.setup

# Build assets
mix assets.build

# Build and minify assets for production
mix assets.deploy
```

### Code Quality
```bash
# Run all pre-commit checks (compile with warnings as errors, format, test)
mix precommit

# Format code
mix format

# Static code analysis
mix credo

# Type checking
mix dialyzer
```

## Architecture

### Clean Architecture Layers

The codebase follows Clean Architecture with strict dependency rules (dependencies flow inward):

```
Presentation Layer (lib/thalamus_web/)
       ↓
Application Layer (lib/thalamus/application/)
       ↓
Domain Layer (lib/thalamus/domain/)
       ↓
Infrastructure Layer (lib/thalamus/infrastructure/)
```

**Key Principle**: Inner layers (Domain) know nothing about outer layers (Infrastructure, Web). Dependencies are inverted using "ports" (behaviour/protocol definitions).

### Domain Layer (`lib/thalamus/domain/`)

Contains pure business logic with no external dependencies:

- **Value Objects** (`value_objects/`): Immutable, validated data types (UserId, Email, AccessToken, etc.)
  - MUST validate on creation
  - MUST implement String.Chars and Jason.Encoder protocols
  - MUST be immutable
  - Example: `UserId`, `Email`, `AccessToken`, `AuthorizationCode`

- **Entities** (`entities/`): Business objects with identity (User, Organization, OAuth2Client)
  - Aggregate roots that encapsulate business rules
  - Can contain Value Objects and other entities

- **Domain Services**: Complex business logic that doesn't belong to a single entity

### Application Layer (`lib/thalamus/application/`)

Orchestrates business workflows:

- **Use Cases** (`use_cases/`): Application-specific business workflows
  - Examples: AuthenticateUser, GenerateTokens, ValidateToken
  - Each use case has a single `execute/1` function
  - Uses ports (interfaces) to interact with infrastructure

- **Ports** (`ports/`): Interfaces (behaviours) for external dependencies
  - Repository interfaces (UserRepository, TokenRepository)
  - Service interfaces (SecurityService, CryptographyService)
  - Implemented by Infrastructure adapters

- **DTOs** (`dtos/`): Data Transfer Objects for use case input/output

### Infrastructure Layer (`lib/thalamus/infrastructure/`)

External concerns and technical details:

- **Adapters** (`adapters/`): Implementations of Application Layer ports
  - PostgreSQL repositories
  - Redis cache adapters
  - Email service adapters
  - Rate limiting adapters

### Presentation Layer (`lib/thalamus_web/`)

Phoenix web interface (controllers, views, templates).

## SOLID Principles (Non-Negotiable)

Every component MUST follow SOLID principles:

1. **Single Responsibility**: Each module has one reason to change
   - Value Objects only handle validation and formatting
   - Use Cases only handle one business workflow

2. **Open/Closed**: Extend without modifying existing code
   - Use protocols for polymorphic behavior
   - Add new use cases without changing existing ones

3. **Liskov Substitution**: Use protocols for polymorphism
   - Implementations must honor protocol contracts

4. **Interface Segregation**: Small, focused interfaces
   - Repository ports are split by entity
   - Service ports are split by concern

5. **Dependency Inversion**: Depend on abstractions (ports), not implementations
   - Application layer defines ports
   - Infrastructure layer implements them

## Code Standards

### Value Object Pattern
```elixir
defmodule Thalamus.Domain.ValueObjects.Example do
  @moduledoc """
  Value Object representing X.

  SOLID Principles Applied:
  - Single Responsibility: Only handles X validation
  - Open/Closed: Can be extended without modification
  """

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  # MUST validate on creation
  def new(value) do
    case validate_format(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Helper functions
  def to_string(%__MODULE__{value: value}), do: value
  def from_string(value), do: new(value)

  # Private validation
  defp validate_format(value) do
    # Validation logic
  end
end

# MUST implement protocols
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.Example do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.Example do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end
```

### Error Handling Pattern
```elixir
# ALWAYS use {:ok, result} | {:error, reason} pattern
def operation(input) do
  with {:ok, validated} <- validate(input),
       {:ok, processed} <- process(validated) do
    {:ok, processed}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### Security Requirements

1. **Token Generation**: ALWAYS use cryptographically secure random generation
```elixir
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
```

2. **Constant-Time Comparison**: For tokens/secrets to prevent timing attacks
```elixir
# Use Plug.Crypto.secure_compare/2
```

3. **Input Validation**: ALWAYS validate
   - Length (min/max)
   - Character set
   - Format (regex)
   - Business rules

## Testing Strategy

### Test Structure
```
test/thalamus/
├── domain/              # Unit tests (no mocks, pure logic)
│   ├── entities/
│   └── value_objects/   # ✓ Complete (23 tests)
├── application/         # Use case tests (with Mox for ports)
│   ├── use_cases/
│   └── dtos/
└── infrastructure/      # Integration tests (with database)
    └── adapters/
```

### Testing Requirements

**Unit Tests** (Domain Layer):
- Test pure business logic
- No database, no mocks
- Fast, isolated tests

**Use Case Tests** (Application Layer):
- Use Mox to mock ports
- Test business workflows
- Verify port interactions

**Integration Tests** (Infrastructure Layer):
- Use real database (Ecto sandbox)
- Test adapter implementations
- Verify external integrations

### Test Standards
```elixir
# Minimum coverage for Value Objects
describe "new/1" do
  test "creates valid object with correct input"
  test "fails with invalid input"
  test "fails with edge cases"
end

describe "protocols" do
  test "implements String.Chars protocol"
  test "implements Jason.Encoder protocol"
end
```

## OAuth2 Implementation

### Supported Scopes

**Standard OAuth2/OIDC Scopes**:
- `openid`, `profile`, `email`, `address`, `phone`, `offline_access`

**ZEA Platform Scopes**:
- `zea:read`, `zea:write`, `zea:admin`
- `synapse:events`, `synapse:metrics`
- `cortex:chat`, `cortex:completions`
- `billing:read`, `billing:write`
- `organizations:read`, `organizations:write`

### Security Features
- PKCE (Proof Key for Code Exchange) - REQUIRED for all authorization code flows
- Token rotation - refresh tokens are rotated on use
- Rate limiting - adaptive rate limiting per user/IP/endpoint
- Audit logging - all security events logged for compliance

## Phoenix/Elixir Specific Notes

### Use Req for HTTP Requests
ALWAYS use the `:req` library (already included) for HTTP requests. AVOID `:httpoison`, `:tesla`, `:httpc`.

### Phoenix v1.8 Guidelines
- Begin LiveView templates with `<Layouts.app flash={@flash}>`
- Use `<.icon name="hero-x-mark">` for Heroicons (imported in core_components.ex)
- Use `<.input>` component for forms (imported from core_components.ex)
- Use `<.link navigate={}>` and `<.link patch={}>` (NOT deprecated `live_redirect`/`live_patch`)

### Ecto Guidelines
- ALWAYS preload associations when accessed in templates
- Schema fields use `:string` type, even for `:text` columns
- Access changeset fields with `Ecto.Changeset.get_field/2`
- Fields set programmatically (like `user_id`) must NOT be in `cast/3`

### HEEx Templates
- Use `~H` sigil or `.html.heex` files
- Use `{...}` for attribute interpolation: `<div id={@id}>`
- Use `<%= ... %>` for block constructs in bodies: `<%= if @condition do %>`
- Use `cond` for multiple conditions (NO `elsif` in Elixir)
- List classes with `class={["px-2", @flag && "py-5"]}`
- HTML comments: `<%!-- comment --%>`

## Project Status

**Current State**: Foundation Complete (Week 1 of 14)
- ✓ 8 Value Objects implemented with 23 passing tests
- ✓ Clean Architecture structure established
- ✓ SOLID principles applied consistently

**Next Steps** (in order):
1. Domain Entities (User, Organization, OAuth2Client)
2. Application Layer Use Cases (AuthenticateUser, GenerateTokens, etc.)
3. Infrastructure Adapters (PostgreSQL repositories, Redis cache)
4. API Controllers & OAuth2 endpoints
5. Security features (MFA, fraud detection, rate limiting)

## Key Dependencies

- **Guardian** (`~> 2.3`) - JWT token management
- **Joken** (`~> 2.6`) - JWT signing & verification
- **Bcrypt** (`~> 3.0`) - Password hashing
- **Pot** (`~> 1.0`) - TOTP for MFA
- **Hammer** (`~> 6.2`) - Rate limiting
- **Oban** (`~> 2.17`) - Background jobs
- **Cachex** (`~> 3.6`) - In-memory caching
- **Redix** (`~> 1.2`) - Redis client
- **Mox** (`~> 1.1`) - Mocking for tests
- **Ex Machina** (`~> 2.7`) - Test factories

## Important Files

- **ARCHITECTURE.md** - Complete system architecture and OAuth2 flows
- **HANDOFF_ARCHITECTURE.md** - Architectural specifications and patterns
- **IMPLEMENTATION_PLAN.md** - 14-week development timeline
- **DEVELOPMENT_TEAM_README.md** - Quick start guide for developers
- **AGENTS.md** - Project documentation (if exists)

## Quality Standards (Non-Negotiable)

- **95%+ test coverage** - Every public function tested
- **Zero Credo warnings** - Clean, idiomatic Elixir
- **Zero Dialyzer warnings** - Type-safe code
- **100% documentation** - All public functions documented with @doc
- **All tests passing** - Before any commit

Run `mix precommit` before committing to verify all quality checks pass.
