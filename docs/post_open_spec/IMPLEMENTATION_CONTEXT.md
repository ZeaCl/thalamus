# Implementation Context for Claude Code Agent
## Thalamus: Agentic Economy Features

**Date Created:** January 16, 2026
**For:** Claude Code Agent (Implementation)
**Your Mission:** Implement agent token generation features for Thalamus following Clean Architecture and SOLID principles

---

## 🎯 What You're Building

You are implementing **high-performance agent authentication features** for Thalamus, an OAuth2 identity server. The goal is to support the **Agentic Economy** - where autonomous AI agents need to authenticate millions of times per month with <5ms p99 latency.

### Key Features to Implement

1. **Agent Token Generation** - OAuth2 tokens with agent metadata (agent_type, task_id, delegation_chain)
2. **Delegation Chains** - Parent-child token relationships with cascade revocation (max depth 5)
3. **ETS Caching** - Sub-millisecond token introspection (6x faster than Redis)
4. **Multi-Tenant Isolation** - Organization-based resource boundaries
5. **MCP Gateway** - Secure gateway for Model Context Protocol servers (future phase)

### Performance Targets

- **p99 Latency**: <5ms for M2M token generation
- **Throughput**: 10,000 RPS per node
- **Cache Hit Rate**: >95%
- **Cost**: $343/month for 10M tokens/month

---

## 📚 Essential Documentation

You MUST read these documents in order before starting:

### 1. Requirements Document
**File:** [01-requirements.md](01-requirements.md)
**What it contains:**
- User stories for AI agents and developers
- 23 functional requirements in EARS format
- Non-functional requirements (performance, security, scalability)
- Architecture and code quality requirements (Clean Architecture, SOLID, 80% test coverage)
- Backward compatibility requirements (REQ-COMPAT-001)

**Key Requirements:**
- `REQ-AGENT-001`: Agent token generation endpoint
- `REQ-AGENT-002`: Delegation chain validation (max depth 5)
- `REQ-ARCH-001`: Clean Architecture compliance (Domain → Application → Infrastructure → Presentation)
- `REQ-ARCH-003`: Test coverage (Domain 100%, Application 90%, Infrastructure 80%)

### 2. Design Documents
**Index:** [02-design-index.md](02-design-index.md)
**What it contains:**
- [02-design-architecture.md](02-design-architecture.md) - System architecture, request flows, Mermaid diagrams
- [02-design-components.md](02-design-components.md) - Code for all layers (Domain, Application, Infrastructure, Web)
- [02-design-database.md](02-design-database.md) - Database schema, migrations, multi-tenant isolation
- [02-design-performance.md](02-design-performance.md) - ETS caching, benchmarking, testing strategy
- [02-design-deployment.md](02-design-deployment.md) - Infrastructure, feature flags, SDKs

**Critical Design Decisions:**
- **ETS-First Caching**: Use ETS (not Redis) for 6x faster lookups
- **Additive Architecture**: Zero breaking changes to existing OAuth2 flows
- **Feature Flag Isolation**: New features behind `ENABLE_AGENT_TOKENS` flag
- **Dependency Injection**: Use cases receive `deps` map with port implementations

### 3. Implementation Tasks
**File:** [03-tasks.md](03-tasks.md)
**What it contains:**
- 8 epics with detailed implementation tasks
- Checkboxes for each task
- File locations for every module
- Acceptance criteria per epic
- Test coverage targets

**Epic Order (execute sequentially):**
1. Foundation (Domain Layer) - Pure business logic
2. Persistence (Infrastructure) - Database migrations, repositories
3. Core Logic (Application) - Use cases, ports
4. API Layer (Presentation) - Controllers, error handling
5. Performance - ETS caching, optimization
6. Security - Multi-tenant isolation, rate limiting
7. Observability - Metrics, logging, monitoring
8. Migration & Rollout - Feature flags, deployment

---

## 🏗️ Architecture Principles (CRITICAL)

### Clean Architecture Layers

You MUST follow strict layer separation:

```
┌─────────────────────────────────────────────────┐
│  Presentation (ThalamusWeb)                     │
│  - Controllers only call use cases              │
│  - No business logic in controllers             │
└──────────────────┬──────────────────────────────┘
                   │ depends on ↓
┌──────────────────▼──────────────────────────────┐
│  Application (Use Cases, Ports, DTOs)           │
│  - Orchestrates business workflows              │
│  - Defines ports (behaviours) for dependencies  │
│  - Dependencies injected via deps map           │
└──────────────────┬──────────────────────────────┘
                   │ depends on ↓
┌──────────────────▼──────────────────────────────┐
│  Domain (Entities, Value Objects)               │
│  - Pure business logic                          │
│  - ZERO external dependencies                   │
│  - No Ecto, Phoenix, or libraries               │
└──────────────────┬──────────────────────────────┘
                   │ implemented by ↑
┌──────────────────▼──────────────────────────────┐
│  Infrastructure (Repositories, Adapters)        │
│  - Implements ports from Application layer      │
│  - Ecto schemas isolated here                   │
│  - External service adapters                    │
└─────────────────────────────────────────────────┘
```

**Import Rules:**
- ❌ Domain MUST NOT import: Ecto, Phoenix, any external libraries
- ❌ Application MUST NOT import: ThalamusWeb, Ecto.Schema
- ❌ Presentation MUST NOT import: Infrastructure directly
- ✅ Infrastructure MAY import: Ecto, external libraries
- ✅ Use cases inject dependencies via `deps` parameter

### SOLID Principles

**Every module you write MUST follow SOLID:**

1. **Single Responsibility** - One module, one reason to change
2. **Open/Closed** - Extend via protocols, not by modifying code
3. **Liskov Substitution** - All port implementations interchangeable
4. **Interface Segregation** - Small, focused port behaviours
5. **Dependency Inversion** - Depend on ports (abstractions), not implementations

**Required in every @moduledoc:**
```elixir
@moduledoc """
Brief description of what this module does.

SOLID Principles:
- Single Responsibility: [explain]
- [Other applicable principles]
"""
```

---

## 🧪 Testing Requirements

### Coverage Targets (ENFORCED)

- **Domain Layer**: 100% (pure unit tests, NO mocks, NO database)
- **Application Layer**: 90% (use case tests with Mox to mock ports)
- **Infrastructure Layer**: 80% (integration tests with real database)
- **Web Layer**: 85% (controller tests with ConnCase)

### Test Organization

```
test/
├── thalamus/
│   ├── domain/              # Pure unit tests (async: true, no DB)
│   │   ├── entities/
│   │   └── value_objects/
│   ├── application/         # Use case tests with Mox (async: true)
│   │   └── use_cases/
│   └── infrastructure/      # Integration tests with DB (async: true, sandbox)
│       └── repositories/
└── thalamus_web/
    └── controllers/         # Controller tests with ConnCase (async: true)
```

### Test Execution Commands

```bash
# Run all tests
mix test

# Run domain tests only (fast, <5 seconds)
mix test test/thalamus/domain/

# Run with coverage (must be ≥80%)
mix test --cover

# Run performance benchmarks
mix test --only benchmark

# Format code before committing
mix format

# Run linter (must pass with --strict)
mix credo --strict
```

---

## 🛠️ Development Workflow

### Step-by-Step for Each Task

1. **Read the task** in [03-tasks.md](03-tasks.md)
2. **Check design** in [02-design-*.md](02-design-index.md) for implementation details
3. **Write tests FIRST** (TDD approach)
   - Domain: Pure unit tests
   - Application: Mox-based tests
   - Infrastructure: Database integration tests
4. **Implement the code** following Clean Architecture
5. **Run tests** - ensure they pass
6. **Check coverage** - must meet target (80%+)
7. **Format code** - `mix format`
8. **Update status** - Mark checkbox in [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)
9. **Commit** with descriptive message

### Example: Implementing AgentType Value Object

```elixir
# 1. Write test first (test/thalamus/domain/value_objects/agent_type_test.exs)
defmodule Thalamus.Domain.ValueObjects.AgentTypeTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.AgentType

  describe "new/1" do
    test "creates valid agent type for autonomous" do
      assert {:ok, %AgentType{value: "autonomous"}} = AgentType.new("autonomous")
    end

    test "creates valid agent type for supervisor" do
      assert {:ok, %AgentType{value: "supervisor"}} = AgentType.new("supervisor")
    end

    test "creates valid agent type for tool" do
      assert {:ok, %AgentType{value: "tool"}} = AgentType.new("tool")
    end

    test "returns error for invalid type" do
      assert {:error, :invalid_agent_type} = AgentType.new("invalid")
    end
  end

  describe "String.Chars protocol" do
    test "converts to string" do
      {:ok, agent_type} = AgentType.new("autonomous")
      assert to_string(agent_type) == "autonomous"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes to JSON" do
      {:ok, agent_type} = AgentType.new("autonomous")
      assert Jason.encode!(agent_type) == ~s("autonomous")
    end
  end
end

# 2. Implement (lib/thalamus/domain/value_objects/agent_type.ex)
defmodule Thalamus.Domain.ValueObjects.AgentType do
  @moduledoc """
  Value Object representing an agent's type.

  Valid types: autonomous, supervisor, tool

  SOLID Principles:
  - Single Responsibility: Only validates and represents agent type
  - Open/Closed: Extensible via protocols without modifying core logic
  """

  @valid_types ~w(autonomous supervisor tool)

  @type t :: %__MODULE__{value: String.t()}
  defstruct [:value]

  @spec new(String.t()) :: {:ok, t()} | {:error, :invalid_agent_type}
  def new(type) when type in @valid_types do
    {:ok, %__MODULE__{value: type}}
  end

  def new(_invalid), do: {:error, :invalid_agent_type}
end

# Protocol implementations
defimpl String.Chars, for: Thalamus.Domain.ValueObjects.AgentType do
  def to_string(%{value: value}), do: value
end

defimpl Jason.Encoder, for: Thalamus.Domain.ValueObjects.AgentType do
  def encode(%{value: value}, opts), do: Jason.Encode.string(value, opts)
end

# 3. Run tests
# mix test test/thalamus/domain/value_objects/agent_type_test.exs

# 4. Check coverage
# mix test --cover

# 5. Format
# mix format

# 6. Update IMPLEMENTATION_STATUS.md - mark "Create AgentType value object" as completed
```

---

## 📋 Status Tracking (IMPORTANT)

### You MUST Update Status Document

**File:** [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)

**After completing ANY task:**
1. Open `IMPLEMENTATION_STATUS.md`
2. Find the epic and task
3. Change `[ ]` to `[x]` for completed tasks
4. Update epic status (Not Started → In Progress → Completed)
5. Update progress percentage
6. Commit the status update

**Example commit message:**
```
feat: implement AgentType value object

- Created AgentType with validation for autonomous/supervisor/tool
- Implemented String.Chars and Jason.Encoder protocols
- Added comprehensive unit tests (100% coverage)
- Updated IMPLEMENTATION_STATUS.md (Epic 1: 20% complete)

Closes #123
```

---

## ⚠️ Critical Rules (DO NOT VIOLATE)

### Backward Compatibility

1. **NEVER modify existing tables** - Only add new tables
2. **NEVER change existing OAuth2 flows** - They must continue working
3. **NEVER break existing tests** - All existing tests must pass unchanged
4. **Use feature flags** - New features behind `ENABLE_AGENT_TOKENS` flag

### Code Quality

1. **All domain code** must have ZERO external dependencies
2. **All public functions** must have `@doc` and `@spec`
3. **All modules** must have `@moduledoc` with SOLID principles
4. **All tests** must use `async: true` when safe
5. **Test coverage** must meet targets (fail build if below 80%)

### Security

1. **Use `:crypto.strong_rand_bytes/1`** for token generation (NOT `Enum.random/1`)
2. **Use `Plug.Crypto.secure_compare/2`** for token validation (prevent timing attacks)
3. **Sanitize user input** - especially the `reason` field (natural language)
4. **Always filter by organization_id** - multi-tenant isolation is CRITICAL
5. **Use parameterized queries** - Ecto enforces this, never raw SQL with interpolation

---

## 🚀 Getting Started Checklist

Before you write any code:

- [ ] Read [01-requirements.md](01-requirements.md) in full
- [ ] Read all design docs: [02-design-index.md](02-design-index.md)
- [ ] Read [03-tasks.md](03-tasks.md) to understand all 8 epics
- [ ] Read this context document completely
- [ ] Open [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) to track progress
- [ ] Run `mix test` to ensure existing tests pass
- [ ] Run `mix deps.get` if needed
- [ ] Start with Epic 1: Foundation (Domain Layer)

---

## 📞 When You Need Help

If you encounter issues:

1. **Check design docs** - Implementation details are in [02-design-components.md](02-design-components.md)
2. **Check CLAUDE.md** - Project conventions in `/Users/dev/Documents/zea/thalamus/CLAUDE.md`
3. **Check existing code** - Look at similar patterns:
   - Value objects: `lib/thalamus/domain/value_objects/email.ex`
   - Entities: `lib/thalamus/domain/entities/user.ex`
   - Use cases: `lib/thalamus/application/use_cases/authenticate_user.ex`
   - Repositories: `lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex`
4. **Ask user** - If something is unclear or requires a decision

---

## 🎯 Success Criteria

Your implementation is successful when:

- ✅ All 8 epics completed (checkboxes in IMPLEMENTATION_STATUS.md)
- ✅ All tests pass: `mix test`
- ✅ Coverage ≥80%: `mix test --cover`
- ✅ No linter warnings: `mix credo --strict`
- ✅ Code formatted: `mix format --check-formatted`
- ✅ All existing OAuth2 tests still pass (backward compatibility)
- ✅ Performance benchmarks meet targets (<5ms p99)
- ✅ Feature flag works (can enable/disable agent tokens)
- ✅ Documentation complete (all modules have @moduledoc and @doc)

---

## 📖 Additional Resources

- **Project README**: `/Users/dev/Documents/zea/thalamus/README.md`
- **CLAUDE.md**: `/Users/dev/Documents/zea/thalamus/CLAUDE.md` - Development conventions
- **Existing tests**: `test/` directory - Examples of test patterns
- **OpenAPI Spec**: `docs/OPENAPI_SPEC.yaml` - API documentation

---

**Good luck! Start with Epic 1 and update IMPLEMENTATION_STATUS.md as you go!** 🚀
