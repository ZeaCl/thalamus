# Design Documentation Index
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.0
**Date:** January 17, 2026
**Status:** Ready for Review (Phase 2)
**Prerequisites:** Phase 1 (Requirements) ✅ Approved

---

## 📚 Design Documents Overview

This index provides navigation for all design documents in Epic 9. Each document focuses on a specific aspect of the RBAC implementation.

---

## 🗂️ Document Structure

### 1. [Architecture & Diagrams](02-design-architecture.md)
**Purpose:** Visual representation of the RBAC system

**Contents:**
- Entity-Relationship Diagram (roles, user_roles, users)
- Component Diagram (Domain → Application → Infrastructure → Web)
- Sequence Diagrams:
  - Role assignment flow
  - Agent token generation with RBAC validation
  - Effective scopes calculation
- Request flow diagrams

**Best for:** Understanding how components interact

---

### 2. [Components & Code](02-design-components.md)
**Purpose:** Complete code implementations for all layers

**Contents:**
- **Domain Layer:**
  - Role entity (with validation logic)
  - Permission value object (scope string validation)
- **Application Layer:**
  - AssignRole use case
  - RevokeRole use case
  - GetEffectiveScopes use case
  - Updated GenerateAgentToken (with delegator validation)
- **Infrastructure Layer:**
  - RoleSchema (Ecto)
  - UserRoleSchema (Ecto)
  - PostgresqlRoleRepository
- **Presentation Layer:**
  - RoleController (CRUD operations)
  - UserRoleController (assignment endpoints)

**Best for:** Copy-paste ready code for implementation

---

### 3. [Database Design](02-design-database.md)
**Purpose:** Database schema, migrations, and indexes

**Contents:**
- Complete SQL migrations (up/down)
- Table schemas with constraints
- Index design and rationale
- Multi-tenant isolation strategy
- Data model examples

**Best for:** Database setup and understanding persistence

---

### 4. [API Specifications](02-design-api.md)
**Purpose:** REST API endpoints, authentication, error handling

**Contents:**
- API endpoint specifications (request/response examples)
- Authentication modes (Human Admin vs M2M Agent)
- Authorization rules
- Error response formats
- Rate limiting configuration

**Best for:** API integration and testing

---

## 🎯 Reading Guide

### For Architects
1. Start with [02-design-architecture.md](02-design-architecture.md) - Visual overview
2. Review [02-design-components.md](02-design-components.md) - Verify SOLID compliance
3. Check [02-design-database.md](02-design-database.md) - Data model validation

### For Backend Developers
1. Start with [02-design-components.md](02-design-components.md) - Implement code
2. Use [02-design-database.md](02-design-database.md) - Run migrations
3. Reference [02-design-api.md](02-design-api.md) - Test endpoints

### For Frontend/Integration Developers
1. Start with [02-design-api.md](02-design-api.md) - API contracts
2. Reference [02-design-architecture.md](02-design-architecture.md) - Flow diagrams
3. Check [02-design-components.md](02-design-components.md) - DTO structures

### For QA/Testers
1. Start with [02-design-api.md](02-design-api.md) - Test scenarios
2. Use [02-design-architecture.md](02-design-architecture.md) - Flow validation
3. Reference [02-design-database.md](02-design-database.md) - Data setup

---

## 🏗️ Architecture Principles (Quick Reference)

### Clean Architecture Layers
```
┌─────────────────────────────────────┐
│  Presentation (Web/API)             │
│  - RoleController                   │
│  - UserRoleController               │
│  - Error handling                   │
└──────────────┬──────────────────────┘
               │ depends on ↓
┌──────────────▼──────────────────────┐
│  Application (Use Cases)            │
│  - AssignRole                       │
│  - RevokeRole                       │
│  - GetEffectiveScopes               │
│  - GenerateAgentToken (updated)     │
└──────────────┬──────────────────────┘
               │ depends on ↓
┌──────────────▼──────────────────────┐
│  Domain (Entities & Value Objects)  │
│  - Role entity                      │
│  - Permission value object          │
└──────────────┬──────────────────────┘
               │ implemented by ↑
┌──────────────▼──────────────────────┐
│  Infrastructure (Repositories)      │
│  - RoleSchema                       │
│  - UserRoleSchema                   │
│  - PostgresqlRoleRepository         │
└─────────────────────────────────────┘
```

### SOLID Principles Applied

**Single Responsibility:**
- Role entity: Only manages role state and validation
- Permission VO: Only validates scope format
- AssignRole use case: Only handles role assignment logic

**Open/Closed:**
- New roles added without modifying existing code
- Scope validation extensible via regex patterns

**Liskov Substitution:**
- All repository implementations interchangeable
- Mock repositories work identically in tests

**Interface Segregation:**
- Separate repository port for roles
- Focused use cases (assign, revoke, get)

**Dependency Inversion:**
- Use cases depend on RoleRepository port (abstraction)
- Infrastructure implements the port (concrete)

---

## 🔑 Key Design Decisions

### 1. Scope Validation Strategy
**Decision:** Format validation only (no whitelist at role creation)

**Rationale:**
- Agents use dynamic MCP scopes (`mcp:gmail:read`, `mcp:slack:write`)
- Cannot predict all future MCP servers
- Security enforced by 4 layers (client, user, parent, org)

**Implementation:** Regex `^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$`

---

### 2. Effective Scopes Calculation
**Decision:** Calculate on-demand with caching (5-minute TTL)

**Rationale:**
- Simple to implement and maintain
- Cache invalidation straightforward (delete key on change)
- Performance acceptable (<10ms p99 even without cache)

**Implementation:**
```elixir
# Cache key: user_effective_scopes:{user_id}
# TTL: 300 seconds
# Invalidate on: user role change OR role scope change
```

---

### 3. Backward Compatibility Strategy
**Decision:** Graceful degradation (users without roles → allow delegation)

**Rationale:**
- Zero breaking changes for existing users
- Easy rollout (no data migration required)
- Opt-in RBAC (assign first role to enable validation)

**Implementation:**
```elixir
case get_effective_scopes(user.id) do
  {:ok, []} -> :ok  # No roles, allow all (backward compatible)
  {:ok, scopes} -> validate_subset(requested, scopes)
end
```

---

### 4. Multi-Tenant Isolation
**Decision:** Foreign key + query filtering at repository level

**Rationale:**
- Database-level referential integrity
- Impossible to access cross-org roles (foreign key constraint)
- All queries automatically scoped by organization_id

**Implementation:**
- Roles table: `organization_id` foreign key with ON DELETE CASCADE
- All queries: `WHERE organization_id = ?`

---

### 5. API Authentication Modes
**Decision:** Two separate modes (Human Admin + M2M Agent)

**Rationale:**
- Humans manage roles (CRUD operations)
- Agents query permissions (read-only, workflow validation)
- Different authorization rules for each mode

**Implementation:**
- Mode 1: Bearer token + `organizations:write` scope
- Mode 2: Agent token + delegator_user_id claim

---

## 🧪 Testing Strategy

### Domain Layer (100% coverage)
- Role entity validation (name, scopes, organization_id)
- Permission value object (regex matching, edge cases)
- Pure unit tests, no mocks, no database

### Application Layer (90% coverage)
- Use case tests with Mox (mock repositories)
- Happy path + all error scenarios
- Cache invalidation behavior

### Infrastructure Layer (85% coverage)
- Repository integration tests with real database
- Multi-tenant isolation tests
- Cascade deletion tests

### API Layer (85% coverage)
- Controller tests with ConnCase
- Authentication/authorization tests
- Error response format tests

---

## 📊 Performance Targets

| Metric | Target | How Measured |
|--------|--------|--------------|
| Effective scopes calculation | <10ms p99 | Benchmark test |
| Role assignment | <50ms p99 | Integration test |
| Cache hit rate | >90% | Production metrics |
| API response time | <100ms p99 | Load test |

---

## 🔗 Cross-References

**From Requirements:**
- REQ-RBAC-010: Core delegator validation → `02-design-components.md` (GenerateAgentToken)
- REQ-RBAC-002: Scope format validation → `02-design-components.md` (Permission VO)
- REQ-RBAC-009: Cache strategy → `02-design-components.md` (GetEffectiveScopes)

**To Implementation:**
- Phase 3 tasks reference these designs
- Implementation status tracked in IMPLEMENTATION_STATUS.md

---

## 📝 Document Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| 02-design-index.md | ✅ Complete | 2026-01-17 |
| 02-design-architecture.md | ✅ Complete | 2026-01-17 |
| 02-design-components.md | ✅ Complete | 2026-01-17 |
| 02-design-database.md | ✅ Complete | 2026-01-17 |
| 02-design-api.md | ✅ Complete | 2026-01-17 |

---

**Phase 2 Status:** ✅ **COMPLETE**

**Next Steps:**
1. ✅ ~~Create all design documents~~ (Complete)
2. Review designs against requirements
3. Approve Phase 2 (Design)
4. Move to Phase 3 (Tasks)

---

**Ready for:** Phase 3 (Tasks) - Implementation task breakdown 🔨
