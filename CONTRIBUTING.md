# Contributing to ZEA Thalamus

Thank you for your interest in contributing to ZEA Thalamus! This document provides guidelines for developers who want to contribute to the project.

---

## 🚀 Quick Start

### Prerequisites

- **Elixir 1.17+** and **Erlang/OTP 26+**
- **PostgreSQL 14+**
- **Redis** (optional, for caching)
- **Git**

### Setup Development Environment

```bash
# Clone the repository
git clone <repository-url>
cd thalamus

# Install dependencies
mix deps.get

# Setup database (creates DB, runs migrations, seeds)
mix ecto.setup

# Run tests to verify setup
mix test

# Start development server
mix phx.server
# Server runs at http://localhost:4000
```

---

## 📁 Project Structure

```
lib/thalamus/
├── domain/                 # Business logic (entities, value objects)
├── application/           # Use cases, ports (interfaces)
├── infrastructure/        # Adapters (database, cache, email)
└── lib/thalamus_web/     # Phoenix controllers, views, templates

test/                      # Mirrors lib/ structure
docs/                      # Documentation
├── INTEGRATION_GUIDE.md  # For external integrators
├── ARCHITECTURE.md       # System architecture
├── DEPLOYMENT_GUIDE.md   # Production deployment
└── internal/             # Internal development docs
```

---

## 🏗️ Architecture Principles

### Clean Architecture

The project follows **Clean Architecture** with strict layer separation:

```
┌─────────────────────────────────────┐
│  Presentation (Phoenix/Controllers) │
└──────────────┬──────────────────────┘
               ↓ depends on
┌──────────────▼──────────────────────┐
│  Application (Use Cases, DTOs)      │
└──────────────┬──────────────────────┘
               ↓ depends on
┌──────────────▼──────────────────────┐
│  Domain (Entities, Value Objects)   │  ← Pure business logic
└──────────────△──────────────────────┘
               ↑ implemented by
┌──────────────┴──────────────────────┐
│  Infrastructure (Repositories, etc)  │
└─────────────────────────────────────┘
```

**Critical Rule**: Inner layers (Domain) NEVER depend on outer layers (Infrastructure, Web). Use ports (behaviours) for dependency inversion.

### SOLID Principles (Non-Negotiable)

All code MUST follow SOLID principles:

1. **Single Responsibility**: Each module has one reason to change
2. **Open/Closed**: Extend without modifying existing code
3. **Liskov Substitution**: Use protocols for polymorphism
4. **Interface Segregation**: Small, focused interfaces
5. **Dependency Inversion**: Depend on abstractions (ports), not implementations

---

## 🧪 Testing

### Test Structure

```
test/
├── thalamus/
│   ├── domain/              # Unit tests (no mocks, pure logic)
│   ├── application/         # Use case tests (with Mox)
│   └── infrastructure/      # Integration tests (with DB)
└── thalamus_web/
    └── controllers/         # Controller tests (HTTP integration)
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/file_test.exs

# Run with coverage
mix test --cover

# Run failed tests only
mix test --failed

# Run tests in watch mode
mix test.watch
```

### Test Standards

- **Domain Layer**: Pure unit tests, no database, no mocks
- **Application Layer**: Use Mox to mock ports
- **Infrastructure**: Integration tests with real database (Ecto sandbox)
- **Controllers**: HTTP integration tests with ConnCase

**Minimum Requirements**:
- 95%+ test coverage
- All edge cases covered
- Clear test descriptions

---

## 📝 Code Standards

### Error Handling

Always use tagged tuples:

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

### Value Objects Pattern

```elixir
defmodule Thalamus.Domain.ValueObjects.Example do
  @moduledoc """
  Value Object for X.

  SOLID Principles Applied:
  - Single Responsibility: Only validates X
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

### Documentation

All public functions MUST have `@doc`:

```elixir
@doc """
Does something useful.

## Examples

    iex> MyModule.my_function("input")
    {:ok, "result"}

## Parameters
- `input` - Description of input

## Returns
- `{:ok, result}` - Success case
- `{:error, reason}` - Error case
"""
def my_function(input) do
  # implementation
end
```

---

## 🔒 Security Requirements

### Cryptographic Operations

**Token Generation** - Always use cryptographically secure random:
```elixir
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
```

**Constant-Time Comparison** - Prevent timing attacks:
```elixir
Plug.Crypto.secure_compare(token1, token2)
```

**Password Hashing** - Use Bcrypt:
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

---

## 🛠️ Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Changes

- Follow code standards
- Write tests FIRST (TDD)
- Ensure SOLID principles
- Add documentation

### 3. Run Quality Checks

```bash
# Format code
mix format

# Run linter
mix credo --strict

# Run tests
mix test

# Type checking (if dialyzer is setup)
mix dialyzer

# All checks at once
mix precommit
```

### 4. Commit Changes

```bash
# Commit with descriptive message
git add .
git commit -m "feat: add user email verification

- Implement email verification use case
- Add verification token generation
- Include tests for happy and error paths
"
```

**Commit Message Format**:
```
<type>: <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

---

## 📋 Pull Request Checklist

Before submitting a PR, ensure:

- [ ] All tests pass (`mix test`)
- [ ] Code is formatted (`mix format`)
- [ ] No linter warnings (`mix credo --strict`)
- [ ] Test coverage is 95%+
- [ ] All public functions documented
- [ ] SOLID principles followed
- [ ] Security best practices applied
- [ ] PR description explains changes
- [ ] Related issue linked (if applicable)

---

## 🐛 Reporting Issues

### Before Creating an Issue

1. Check if issue already exists
2. Verify it's not a configuration problem
3. Test with latest version

### Issue Template

```markdown
**Description**
Clear description of the issue

**Steps to Reproduce**
1. Step one
2. Step two
3. ...

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- Elixir version:
- Erlang version:
- PostgreSQL version:
- OS:

**Logs**
Paste relevant logs here
```

---

## 📚 Resources

### Essential Documentation

- **[README.md](README.md)** - Project overview and quick start
- **[INTEGRATION_GUIDE.md](docs/INTEGRATION_GUIDE.md)** - Integration guide for external teams
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture details
- **[DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** - Production deployment
- **[CLAUDE.md](CLAUDE.md)** - Instructions for AI assistants

### External Resources

- [Elixir Documentation](https://hexdocs.pm/elixir/)
- [Phoenix Framework](https://hexdocs.pm/phoenix/)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)

---

## 💡 Development Tips

### Database

```bash
# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Create migration
mix ecto.gen.migration add_feature

# Run migrations
mix ecto.migrate

# Rollback
mix ecto.rollback
```

### IEx Console

```bash
# Start IEx with application loaded
iex -S mix

# Reload code after changes
iex> recompile()
```

### Docker

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f thalamus

# Stop all services
docker-compose down
```

---

## 🎯 Code Review Guidelines

### What We Look For

✅ **Good**:
- Clear, descriptive variable names
- Small, focused functions
- Comprehensive tests
- Proper error handling
- Security best practices

❌ **Bad**:
- Magic numbers without explanation
- Large functions (>20 lines)
- Missing tests
- Unhandled error cases
- Security vulnerabilities

### Review Process

1. **Automated Checks**: CI runs tests, linter, formatter
2. **Code Review**: Maintainer reviews code quality
3. **Testing**: Reviewer tests functionality
4. **Approval**: At least one approval required
5. **Merge**: Squash and merge to main

---

## 📞 Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Create an issue with template
- **Security**: Email security@example.com (do not create public issue)

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

---

**Thank you for contributing to ZEA Thalamus! 🚀**
