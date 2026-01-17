# Architecture & Diagrams
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.0
**Date:** January 17, 2026
**Status:** Design Phase (Phase 2)

---

## 📐 System Architecture

### Clean Architecture Layers

```
┌──────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (lib/thalamus_web/)              │
│                                                       │
│  ┌──────────────┐  ┌──────────────────┐             │
│  │ RoleController│  │UserRoleController│             │
│  │   (CRUD)     │  │  (Assignment)     │             │
│  └──────┬───────┘  └────────┬──────────┘             │
│         │                    │                        │
└─────────┼────────────────────┼────────────────────────┘
          │                    │
          ▼                    ▼
┌──────────────────────────────────────────────────────┐
│  APPLICATION LAYER (lib/thalamus/application/)       │
│                                                       │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐│
│  │  AssignRole  │  │ RevokeRole  │  │GetEffective  ││
│  │  Use Case    │  │  Use Case   │  │Scopes UseCase││
│  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘│
│         │                 │                 │        │
│         └─────────────────┼─────────────────┘        │
│                           │                          │
│  Ports (Interfaces):      │                          │
│  • RoleRepository ────────┘                          │
│  • UserRepository                                    │
│  • AuditLogger                                       │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────┐
│  DOMAIN LAYER (lib/thalamus/domain/)                 │
│                                                       │
│  ┌───────────────┐      ┌──────────────────┐        │
│  │  Role Entity  │      │Permission Value  │        │
│  │               │      │     Object       │        │
│  │ • validate()  │      │ • new(scope)     │        │
│  │ • add_scope() │      │ • valid_format?()│        │
│  └───────────────┘      └──────────────────┘        │
│                                                       │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼ (implemented by)
┌──────────────────────────────────────────────────────┐
│  INFRASTRUCTURE LAYER                                 │
│  (lib/thalamus/infrastructure/)                       │
│                                                       │
│  Schemas:                 Repositories:               │
│  • RoleSchema            • PostgresqlRoleRepository  │
│  • UserRoleSchema        • to_domain()               │
│  • Migrations            • to_changeset()            │
│                                                       │
└──────────────────────────────────────────────────────┘
```

---

## 🗄️ Entity-Relationship Diagram

```mermaid
erDiagram
    organizations ||--o{ roles : "has many"
    roles ||--o{ user_roles : "has many"
    users ||--o{ user_roles : "has many"
    users }o--|| organizations : "belongs to"

    organizations {
        uuid id PK
        string name
        enum status
        timestamp created_at
    }

    roles {
        uuid id PK
        uuid organization_id FK
        string name UK
        text description
        text[] scopes
        timestamp created_at
        timestamp updated_at
    }

    user_roles {
        uuid id PK
        uuid user_id FK
        uuid role_id FK
        uuid assigned_by FK
        timestamp assigned_at
    }

    users {
        uuid id PK
        uuid organization_id FK
        string email UK
        string password_hash
        enum status
        timestamp created_at
    }
```

**Key Relationships:**
- **Organization → Roles**: One-to-many (organization owns roles)
- **Role → UserRoles**: One-to-many (role assigned to many users)
- **User → UserRoles**: One-to-many (user has many roles)
- **Organization → Users**: One-to-many (multi-tenant isolation)

**Constraints:**
- `roles.name` unique within organization (composite unique index)
- `user_roles(user_id, role_id)` unique (prevent duplicate assignments)
- Cascade delete: Organization deleted → Roles deleted → UserRoles deleted

---

## 🔄 Sequence Diagrams

### 1. Role Assignment Flow

```mermaid
sequenceDiagram
    participant Admin as Organization Admin
    participant API as RoleController
    participant UC as AssignRole UseCase
    participant RoleRepo as RoleRepository
    participant UserRepo as UserRepository
    participant Cache as Cache Service
    participant Audit as AuditLogger

    Admin->>API: POST /api/users/:id/roles<br/>{role_id}
    API->>API: Authenticate (Bearer token)
    API->>API: Authorize (organizations:write)
    API->>UC: execute(user_id, role_id, deps)

    UC->>UserRepo: find_by_id(user_id)
    UserRepo-->>UC: {:ok, user}

    UC->>RoleRepo: find_by_id(role_id)
    RoleRepo-->>UC: {:ok, role}

    UC->>UC: Validate same organization

    UC->>RoleRepo: assign_to_user(user, role)
    RoleRepo->>RoleRepo: Check duplicate
    RoleRepo->>RoleRepo: Insert user_role
    RoleRepo-->>UC: {:ok, user_role}

    UC->>Cache: invalidate(user_effective_scopes:user_id)
    Cache-->>UC: :ok

    UC->>Audit: log(role_assigned event)
    Audit-->>UC: :ok

    UC-->>API: {:ok, user_role}
    API-->>Admin: 201 Created<br/>{user_id, role_id, assigned_at}
```

---

### 2. Agent Token Generation with RBAC Validation

```mermaid
sequenceDiagram
    participant Agent as AI Agent Workflow
    participant API as AgentTokenController
    participant UC as GenerateAgentToken
    participant UserRepo as UserRepository
    participant ClientRepo as OAuth2ClientRepository
    participant TokenRepo as AgentTokenRepository
    participant Cache as Cache Service

    Agent->>API: POST /oauth/agent-token<br/>{client_id, client_secret,<br/>delegator_user_id, scopes}

    API->>UC: execute(request, deps)

    UC->>ClientRepo: find_by_client_id(client_id)
    ClientRepo-->>UC: {:ok, client}

    UC->>UC: Authenticate client credentials

    UC->>UserRepo: find_by_id(delegator_user_id)
    UserRepo-->>UC: {:ok, delegator}

    UC->>UC: Validate delegator active

    Note over UC,Cache: RBAC VALIDATION (NEW)
    UC->>Cache: get(user_effective_scopes:user_id)

    alt Cache Hit
        Cache-->>UC: {:ok, cached_scopes}
    else Cache Miss
        UC->>UserRepo: get_user_roles(user_id)
        UserRepo-->>UC: {:ok, [role1, role2]}
        UC->>UC: Calculate union of role scopes
        UC->>Cache: set(user_effective_scopes:user_id, scopes, 300)
    end

    UC->>UC: Validate requested ⊆ effective_scopes

    alt Validation Failed
        UC-->>API: {:error, :delegator_insufficient_permissions}
        API-->>Agent: 403 Forbidden<br/>{error: "Delegator lacks scopes"}
    else Validation Passed
        UC->>UC: Validate scopes ⊆ client.allowed_scopes
        UC->>UC: Validate scopes ⊆ parent.scopes (if child)
        UC->>TokenRepo: save(agent_token)
        TokenRepo-->>UC: {:ok, token}
        UC-->>API: {:ok, token_response}
        API-->>Agent: 200 OK<br/>{access_token, expires_in}
    end
```

---

### 3. Effective Scopes Calculation Flow

```mermaid
sequenceDiagram
    participant Client as API Client
    participant API as EffectiveScopesController
    participant UC as GetEffectiveScopes
    participant Cache as Cache Service
    participant Repo as RoleRepository

    Client->>API: GET /api/users/:id/effective-scopes
    API->>API: Authenticate (Bearer)
    API->>API: Authorize (self OR admin)

    API->>UC: execute(user_id, deps)

    UC->>Cache: get(user_effective_scopes:user_id)

    alt Cache Hit (90% of requests)
        Cache-->>UC: {:ok, cached_scopes}
        UC-->>API: {:ok, scopes}
        API-->>Client: 200 OK<br/>{effective_scopes, from_cache: true}
    else Cache Miss
        UC->>Repo: get_user_roles(user_id)
        Repo-->>UC: {:ok, [role1, role2, role3]}

        UC->>UC: Extract scopes from each role
        Note over UC: role1.scopes: ["read:data"]<br/>role2.scopes: ["write:data"]<br/>role3.scopes: ["read:data", "admin"]

        UC->>UC: Calculate union (deduplicate)
        Note over UC: Union: ["read:data", "write:data", "admin"]

        UC->>Cache: set(user_effective_scopes:user_id,<br/>scopes, ttl=300)
        Cache-->>UC: :ok

        UC-->>API: {:ok, scopes}
        API-->>Client: 200 OK<br/>{effective_scopes, from_cache: false}
    end
```

---

### 4. Role Scope Update with Cache Invalidation

```mermaid
sequenceDiagram
    participant Admin as Organization Admin
    participant API as RoleController
    participant UC as UpdateRole
    participant Repo as RoleRepository
    participant Cache as Cache Service
    participant Audit as AuditLogger

    Admin->>API: PATCH /api/roles/:id<br/>{scopes: ["new:scope"]}

    API->>UC: execute(role_id, new_scopes, deps)

    UC->>Repo: find_by_id(role_id)
    Repo-->>UC: {:ok, role}

    Note over UC: Store old scopes for audit
    UC->>UC: old_scopes = role.scopes

    UC->>Repo: update_scopes(role_id, new_scopes)
    Repo-->>UC: {:ok, updated_role}

    Note over UC,Cache: Cache Invalidation
    UC->>Repo: get_users_with_role(role_id)
    Repo-->>UC: {:ok, [user_id1, user_id2, ...]}

    loop For each affected user
        UC->>Cache: delete(user_effective_scopes:user_id)
    end

    UC->>Audit: log(role_updated,<br/>old_scopes, new_scopes)
    Audit-->>UC: :ok

    UC-->>API: {:ok, updated_role}
    API-->>Admin: 200 OK<br/>{role, affected_users: 15}
```

---

## 🏗️ Component Diagram

```mermaid
graph TB
    subgraph "Presentation Layer"
        RC[RoleController]
        URC[UserRoleController]
        ATC[AgentTokenController<br/>Updated]
    end

    subgraph "Application Layer"
        AR[AssignRole<br/>UseCase]
        RR[RevokeRole<br/>UseCase]
        GES[GetEffectiveScopes<br/>UseCase]
        GAT[GenerateAgentToken<br/>UseCase UPDATED]

        RP[RoleRepository<br/>Port]
        UP[UserRepository<br/>Port]
        AL[AuditLogger<br/>Port]
        CS[CacheService<br/>Port]
    end

    subgraph "Domain Layer"
        RE[Role Entity]
        PVO[Permission<br/>Value Object]
    end

    subgraph "Infrastructure Layer"
        RS[RoleSchema]
        URS[UserRoleSchema]
        PRR[PostgresqlRoleRepository]
        CA[Cachex Adapter]
    end

    RC --> AR
    RC --> RR
    URC --> AR
    URC --> RR
    ATC --> GAT

    AR --> RP
    AR --> UP
    AR --> AL
    RR --> RP
    RR --> AL
    GES --> RP
    GES --> CS
    GAT --> RP
    GAT --> UP
    GAT --> CS

    AR -.uses.-> RE
    GAT -.uses.-> PVO

    RP -.implemented by.-> PRR
    CS -.implemented by.-> CA

    PRR --> RS
    PRR --> URS

    style GAT fill:#ff9,stroke:#333,stroke-width:2px
    style PVO fill:#ff9,stroke:#333,stroke-width:2px
    style RP fill:#9f9,stroke:#333,stroke-width:2px
```

**Legend:**
- 🟨 Yellow: Components updated/created in Epic 9
- 🟩 Green: New ports/interfaces
- → Solid line: Direct dependency
- ··> Dotted line: Implementation/usage

---

## 🔐 Security Architecture

### Multi-Tenant Isolation

```
┌──────────────────────────────────────────────┐
│  Organization A (org_acme)                   │
│  ┌─────────────────────────────────────────┐ │
│  │ Roles:                                  │ │
│  │  - "Admin" [all scopes]                 │ │
│  │  - "Developer" [read:*, write:code]     │ │
│  │                                         │ │
│  │ Users:                                  │ │
│  │  - user_alice (roles: Admin)            │ │
│  │  - user_bob (roles: Developer)          │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Organization B (org_beta)                   │
│  ┌─────────────────────────────────────────┐ │
│  │ Roles:                                  │ │
│  │  - "Manager" [read:*, mcp:*]            │ │
│  │                                         │ │
│  │ Users:                                  │ │
│  │  - user_charlie (roles: Manager)        │ │
│  └─────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘

Database Constraints:
✅ roles.organization_id → organizations.id (FK)
✅ users.organization_id → organizations.id (FK)
✅ All queries: WHERE organization_id = ?

Security Guarantees:
❌ user_alice CANNOT assign role from org_beta
❌ user_charlie CANNOT see roles from org_acme
✅ Complete data isolation
```

---

## 📊 Data Flow Diagrams

### Write Flow: Role Assignment

```
Admin Request
     │
     ▼
[Authentication] ──────> Verify Bearer token
     │
     ▼
[Authorization] ───────> Check organizations:write scope
     │
     ▼
[Input Validation] ────> Validate user_id, role_id format
     │
     ▼
[Business Logic]
  ├─> Fetch user from DB
  ├─> Fetch role from DB
  ├─> Validate same organization
  ├─> Check not already assigned
  └─> Insert user_role record
     │
     ▼
[Cache Invalidation] ──> DELETE user_effective_scopes:{user_id}
     │
     ▼
[Audit Logging] ───────> Log role_assigned event
     │
     ▼
[Response] ────────────> 201 Created {user_id, role_id, assigned_at}
```

### Read Flow: Effective Scopes Query

```
Agent/User Request
     │
     ▼
[Authentication] ──────> Verify Bearer token (agent or user)
     │
     ▼
[Authorization] ───────> Verify self OR admin
     │
     ▼
[Cache Check]
     ├─> Cache HIT ──────> Return cached scopes (fast path)
     │
     └─> Cache MISS ─────> Calculate from DB
           │
           ▼
        [Query DB] ──────> SELECT roles WHERE user_id IN user_roles
           │
           ▼
        [Calculate Union] > Deduplicate scopes from all roles
           │
           ▼
        [Store Cache] ───> SET user_effective_scopes:{id}, TTL=300s
           │
           ▼
        [Return] ────────> Scopes array
```

---

## 🎯 Performance Characteristics

### Latency Targets

| Operation | Target p50 | Target p99 | Notes |
|-----------|------------|------------|-------|
| Get effective scopes (cache hit) | <2ms | <5ms | Cachex lookup |
| Get effective scopes (cache miss) | <8ms | <15ms | DB query + calculation |
| Assign role | <30ms | <50ms | DB insert + cache invalidate |
| Revoke role | <30ms | <50ms | DB delete + cache invalidate |
| Update role scopes | <50ms | <100ms | DB update + multi-user cache invalidate |

### Cache Strategy

```
Cache Key Format: user_effective_scopes:{user_id}
Cache Value: ["scope1", "scope2", ...]
TTL: 300 seconds (5 minutes)

Invalidation Events:
1. User role assigned → DELETE user_effective_scopes:{user_id}
2. User role revoked → DELETE user_effective_scopes:{user_id}
3. Role scopes updated → DELETE user_effective_scopes:{user_id} for ALL users with that role

Expected Hit Rate: >90% (roles change infrequently)
```

---

## 🧩 Integration Points

### With Existing Systems

**1. GenerateAgentToken Use Case (UPDATED)**
```elixir
# Before Epic 9
defp validate_delegator_has_scopes(_user, _scopes, _deps) do
  :ok  # Always allowed
end

# After Epic 9
defp validate_delegator_has_scopes(user, requested_scopes, deps) do
  case deps.user_repository.get_effective_scopes(user.id) do
    {:ok, []} -> :ok  # Backward compatible
    {:ok, user_scopes} ->
      requested_set = MapSet.new(requested_scopes)
      user_set = MapSet.new(user_scopes)

      if MapSet.subset?(requested_set, user_set) do
        :ok
      else
        {:error, :delegator_insufficient_permissions}
      end
  end
end
```

**2. UserRepository Port (EXTENDED)**
```elixir
# New callback added
@callback get_effective_scopes(user_id :: binary()) ::
  {:ok, [String.t()]} | {:error, :not_found}
```

---

## 📝 Design Patterns Used

### 1. Repository Pattern
- **Port**: `RoleRepository` behaviour (application layer)
- **Adapter**: `PostgresqlRoleRepository` (infrastructure layer)
- **Benefit**: Database-agnostic business logic

### 2. Use Case Pattern (Clean Architecture)
- **AssignRole**, **RevokeRole**, **GetEffectiveScopes**
- **Benefit**: Single responsibility, testable with mocks

### 3. Value Object Pattern
- **Permission** (scope string validation)
- **Benefit**: Validation centralized, immutable

### 4. Strategy Pattern (Cache Invalidation)
- **Multi-user invalidation**: When role scopes change
- **Single-user invalidation**: When user roles change
- **Benefit**: Flexible, cache stays consistent

---

**Document Status:** ✅ Complete
**Next:** [02-design-components.md](02-design-components.md) - Code implementations
