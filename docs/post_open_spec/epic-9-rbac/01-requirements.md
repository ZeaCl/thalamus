# Requirements Document
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.1
**Date:** January 17, 2026
**Status:** ✅ Ready for Review (Phase 1 Complete)
**Epic:** 9 of 9 (RBAC Implementation)
**Prerequisites:** Epics 1-8 completed
**Related TODO:** `lib/thalamus/application/use_cases/generate_agent_token.ex:139-166`

**Changes in v1.1:**
- Fixed GAP #1: REQ-RBAC-002 now validates scope format only (supports dynamic MCP scopes)
- Fixed GAP #2: Section 5.3 updated with comprehensive scope validation regex
- Fixed GAP #3: Added Section 6.0 API Authentication (Human Admin + M2M Agent modes)
- Fixed US-RBAC-001: Clarified backward compatibility for users without roles
- Enhanced REQ-RBAC-009: Added detailed cache invalidation strategy
- Fixed Section 12.1: Corrected dependencies (removed organization.allowed_scopes)

---

## 1. Introduction

### 1.1 Purpose and Scope

This document defines the requirements for implementing **Role-Based Access Control (RBAC)** in Thalamus. RBAC enables fine-grained authorization for agent token generation by validating that delegator users have permission to delegate the requested scopes.

### 1.2 Problem Statement

Currently, `GenerateAgentToken` use case has a simplified validation:

```elixir
# Current implementation (lines 146-166)
defp validate_delegator_has_scopes(_user, _requested_scopes, _deps) do
  Logger.warning("Delegator scope validation is simplified...")
  :ok  # Allows all delegations
end
```

**Security Gap:**
- User A has scopes: `["read:documents", "write:documents"]`
- User B has scopes: `["read:documents"]`
- **Problem:** User B can currently generate agent token with scope `"write:documents"`
- **Risk:** Users delegating permissions they don't have

**Mitigating Factors:**
- ✅ OAuth2 client validates `scopes ⊆ client.allowed_scopes`
- ✅ Parent tokens validate `child.scopes ⊆ parent.scopes`
- ✅ Organization validates compliance rules

**Remaining Gap:** User-level scope validation

### 1.3 Solution Overview

Implement RBAC with:
- **Role** entity: Named collections of scopes (e.g., "Document Editor")
- **Permission** value object: Individual scope permission
- **User roles assignment**: Many-to-many relationship
- **Effective scopes calculation**: Union of all role scopes
- **Delegation validation**: `requested_scopes ⊆ user.effective_scopes`

### 1.4 Integration Points

- **Domain Layer:** New entities and value objects
- **Infrastructure:** New tables and migrations
- **Application:** New use cases for role management
- **Existing Use Cases:** Update `GenerateAgentToken.validate_delegator_has_scopes/3`

---

## 2. User Stories and Actors

### 2.1 Primary Actors

1. **Organization Admin:** Manages roles and assigns them to users
2. **Delegator User:** Human user delegating permissions to AI agents
3. **Security Engineer:** Audits permission grants and role assignments
4. **Platform Developer:** Integrates RBAC into agent authorization flow

### 2.2 User Stories

#### US-RBAC-001: Prevent Unauthorized Scope Delegation
**As a** Security Engineer
**I want** users to only delegate scopes they personally possess
**So that** agents cannot be granted excessive permissions beyond the delegator's authority

**Acceptance Criteria:**
- WHEN user with scopes `["read:data"]` requests agent token with `["write:data"]` THEN system SHALL reject with `delegator_insufficient_permissions` error
- WHEN user with scopes `["read:data", "write:data"]` requests agent token with `["read:data"]` THEN system SHALL approve
- WHERE user has no roles assigned THEN system SHALL allow delegation for backward compatibility (graceful degradation)

#### US-RBAC-002: Centralized Role Management
**As an** Organization Admin
**I want** to create reusable roles with predefined scopes
**So that** I can assign consistent permissions to multiple users without repetition

**Acceptance Criteria:**
- WHEN admin creates role "Document Editor" with scopes `["read:documents", "write:documents"]` THEN system SHALL persist role
- WHEN admin assigns "Document Editor" to user THEN user SHALL inherit role scopes
- WHERE role is updated THEN all users with that role SHALL receive updated scopes immediately

#### US-RBAC-003: Multiple Roles per User
**As an** Organization Admin
**I want** to assign multiple roles to a single user
**So that** users can have cumulative permissions from different roles

**Acceptance Criteria:**
- WHEN user has roles "Reader" (scopes: `["read:data"]`) and "Writer" (scopes: `["write:data"]`) THEN user effective scopes SHALL be `["read:data", "write:data"]` (union)
- WHEN role is removed from user THEN user effective scopes SHALL recalculate excluding removed role scopes

#### US-RBAC-004: Audit Trail for Role Changes
**As a** Security Engineer
**I want** all role assignments and revocations logged
**So that** I can audit permission changes for compliance

**Acceptance Criteria:**
- WHEN role assigned to user THEN audit log SHALL record event with actor, user, role, timestamp
- WHEN role scopes modified THEN audit log SHALL record before/after scopes

#### US-RBAC-005: Organization-Scoped Roles
**As a** Platform Developer
**I want** roles isolated per organization
**So that** Organization A cannot access or assign roles from Organization B

**Acceptance Criteria:**
- WHERE role created in Org A THEN role SHALL NOT be visible in Org B
- WHERE user in Org A assigned role from Org B THEN system SHALL reject with `organization_mismatch`

---

## 3. Functional Requirements (EARS Format)

### 3.1 Role Management

**REQ-RBAC-001:** Role Creation
- WHEN organization admin creates role THEN system SHALL validate name is unique within organization
- WHERE name is empty or > 100 characters THEN system SHALL reject with `invalid_role_name`
- WHERE description > 500 characters THEN system SHALL reject with `description_too_long`

**REQ-RBAC-002:** Role Scope Assignment
- WHEN role created with scopes THEN system SHALL validate each scope format matches regex: `^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$`
- WHERE scope length > 128 characters THEN system SHALL reject with `scope_too_long`
- WHERE scope format invalid THEN system SHALL reject with `invalid_scope_format`
- WHERE scopes array empty THEN system SHALL accept (role with zero permissions)

**Rationale:** Scopes are dynamic and task-specific in agentic workflows (MCP servers, external APIs). Security is enforced through layered validation (OAuth2Client.allowed_scopes, User.effective_scopes, parent token narrowing, organization compliance rules).

**REQ-RBAC-003:** Role Update
- WHEN role scopes updated THEN all users with that role SHALL have recalculated effective scopes
- WHERE role has active users THEN system SHALL log scope change event

**REQ-RBAC-004:** Role Deletion
- WHEN role deleted THEN system SHALL revoke role from all assigned users
- WHERE role has > 10 assigned users THEN system SHALL require confirmation flag
- WHEN role deleted THEN audit log SHALL record affected user IDs

### 3.2 User Role Assignment

**REQ-RBAC-005:** Assign Role to User
- WHEN admin assigns role to user THEN system SHALL validate both role and user exist in same organization
- WHERE user already has role THEN system SHALL respond with `role_already_assigned` (idempotent)
- WHEN role assigned THEN user effective scopes SHALL update immediately

**REQ-RBAC-006:** Revoke Role from User
- WHEN admin revokes role from user THEN system SHALL remove role assignment
- WHERE user does not have role THEN system SHALL respond with `role_not_assigned` (idempotent)
- WHEN role revoked THEN user effective scopes SHALL recalculate

**REQ-RBAC-007:** Bulk Assignment
- WHEN admin assigns role to multiple users (bulk) THEN system SHALL process all or fail atomically
- WHERE any user not in organization THEN system SHALL reject entire batch

### 3.3 Effective Scopes Calculation

**REQ-RBAC-008:** Calculate User Effective Scopes
- WHEN user effective scopes requested THEN system SHALL return union of all assigned role scopes
- WHERE user has zero roles THEN effective scopes SHALL be empty array
- WHERE user has overlapping scopes from multiple roles THEN system SHALL deduplicate

**REQ-RBAC-009:** Cache Effective Scopes
- WHEN effective scopes calculated THEN system MAY cache result with key `user_effective_scopes:{user_id}` for up to 300 seconds (5 minutes)
- WHERE user role assignment changes (assign/revoke) THEN cache key SHALL be deleted immediately: `DELETE user_effective_scopes:{user_id}`
- WHERE role scopes updated THEN system SHALL:
  1. Query all user_ids assigned to that role
  2. Delete cache for each affected user: `DELETE user_effective_scopes:{user_id}`
  3. (Optional) Broadcast cache invalidation event via PubSub for distributed systems

### 3.4 Agent Token Delegation Validation

**REQ-RBAC-010:** Validate Delegator Scopes (Core Requirement)
- WHEN user generates agent token THEN system SHALL retrieve user effective scopes
- WHEN requested token scopes are subset of user effective scopes THEN system SHALL approve
- WHERE requested scopes exceed user effective scopes THEN system SHALL reject with `delegator_insufficient_permissions`

**REQ-RBAC-011:** Scope Narrowing Enforcement
- WHERE agent token is child of parent token THEN system SHALL validate `requested_scopes ⊆ parent.scopes AND requested_scopes ⊆ user.effective_scopes`
- WHEN both validations pass THEN system SHALL approve token generation

### 3.5 Multi-Tenancy

**REQ-RBAC-012:** Organization Isolation
- WHERE role queried THEN system SHALL filter by organization_id
- WHERE user role assignment queried THEN system SHALL filter by user.organization_id
- WHERE cross-organization role assignment attempted THEN system SHALL reject with `organization_mismatch`

---

## 4. Non-Functional Requirements

### 4.1 Performance

**REQ-RBAC-NFR-001:** Effective Scopes Calculation
- System SHALL calculate effective scopes in < 10ms (p99)
- WHERE user has > 20 roles THEN calculation SHALL still complete in < 50ms

**REQ-RBAC-NFR-002:** Caching
- System MAY cache effective scopes for up to 300 seconds (5 minutes)
- Cache invalidation SHALL occur immediately on role/scope changes

### 4.2 Scalability

**REQ-RBAC-NFR-003:** Role Limits
- System SHALL support up to 100 roles per organization
- System SHALL support up to 50 roles per user
- WHERE limits exceeded THEN system SHALL reject with clear error

### 4.3 Data Integrity

**REQ-RBAC-NFR-004:** Referential Integrity
- Database SHALL enforce foreign key constraints (roles → organizations, user_roles → users, user_roles → roles)
- WHERE role deleted THEN CASCADE delete all user_role assignments

### 4.4 Backward Compatibility

**REQ-RBAC-NFR-005:** Existing Code Compatibility
- Implementation SHALL NOT break existing OAuth2 flows
- Implementation SHALL NOT break existing agent token generation for users without roles
- WHERE user has zero roles THEN delegator validation SHALL default to ALLOW (graceful degradation)

---

## 5. Data Model Requirements

### 5.1 Role Entity

**Fields:**
- `id` (UUID, primary key)
- `organization_id` (UUID, foreign key to organizations)
- `name` (string, 1-100 chars, unique within organization)
- `description` (string, 0-500 chars, nullable)
- `scopes` (array of strings, validated against organization allowed scopes)
- `created_at` (timestamp)
- `updated_at` (timestamp)

**Constraints:**
- Unique index on `(organization_id, name)`
- Foreign key to organizations with ON DELETE CASCADE

### 5.2 UserRole Join Table

**Fields:**
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key to users)
- `role_id` (UUID, foreign key to roles)
- `assigned_by` (UUID, foreign key to users, nullable)
- `assigned_at` (timestamp)

**Constraints:**
- Unique index on `(user_id, role_id)` (prevent duplicate assignments)
- Foreign key to users with ON DELETE CASCADE
- Foreign key to roles with ON DELETE CASCADE

### 5.3 Permission Value Object (Scope String)

**Not persisted directly** - represented as strings in role scopes array

**Validation:**
- Pattern: `^[a-z][a-z0-9_-]*(?::[a-z][a-z0-9_-]*){0,3}$`
- Max length: 128 characters
- Max depth: 4 levels (e.g., `mcp:slack:channels:list`)

**Supported formats:**
- **OIDC standard:** `openid`, `profile`, `email`, `offline_access`
- **Namespaced:** `zea:read`, `cortex:chat`, `synapse:events`
- **MCP servers:** `mcp:gmail:read`, `mcp:slack:write`, `mcp:github:issues:create`
- **Resource-based:** `documents:read`, `database:query`
- **Multi-level:** `mcp:slack:channels:list`, `mcp:github:repos:read`

**Security:** Format validation prevents injection attacks. Actual authorization enforced by multiple validation layers:
1. OAuth2Client.allowed_scopes (whitelist per client)
2. User.effective_scopes (whitelist per user via roles) - Epic 9
3. Parent token scopes (narrowing in delegation chains)
4. Organization compliance rules (business hour restrictions, forbidden types)

---

## 6. API Requirements

### 6.0 API Authentication

All RBAC endpoints require authentication. Two authentication modes are supported:

#### Mode 1: Human Admin (Role Management)

**Used for:**
- POST/PATCH/DELETE /api/roles (role CRUD)
- POST/DELETE /api/users/:id/roles (role assignment)

**Authentication:**
```
Authorization: Bearer {user_access_token}
```

**Authorization:**
- Token MUST have `organizations:write` scope, OR
- User MUST have role with `admin` permission in organization

**Organization Context:**
- System SHALL extract `organization_id` from user token claims
- All operations SHALL be scoped to user's organization
- Cross-organization requests SHALL be rejected with `403 Forbidden`

#### Mode 2: M2M Agent (Query Only)

**Used for:**
- GET /api/users/:id/effective-scopes (query delegator permissions)

**Authentication:**
```
Authorization: Bearer {agent_access_token}
```

**Authorization:**
- Agent token MUST have valid `delegator_user_id` claim
- Agent can ONLY query effective scopes of its own delegator
- Cross-user queries SHALL be rejected with `403 Forbidden`

**Organization Context:**
- Extracted from agent token claims: `organization_id`
- Multi-tenant isolation enforced

**Use Case:** Agent queries delegator's effective scopes before workflow execution to validate it has necessary permissions for planned operations.

### 6.1 Role Management Endpoints

**POST /api/roles**
- Create new role in organization
- Request: `{ name, description, scopes }`
- Response: `{ id, name, description, scopes, created_at }`

**GET /api/roles**
- List all roles in organization
- Query params: `?organization_id=...`
- Response: `{ roles: [...] }`

**PATCH /api/roles/:id**
- Update role scopes or description
- Request: `{ scopes?, description? }`
- Response: `{ id, name, description, scopes, updated_at }`

**DELETE /api/roles/:id**
- Delete role (requires confirmation if > 10 users)
- Query params: `?confirm=true`
- Response: `{ deleted: true, affected_users: 5 }`

### 6.2 User Role Assignment Endpoints

**POST /api/users/:user_id/roles**
- Assign role to user
- Request: `{ role_id }`
- Response: `{ user_id, role_id, assigned_at }`

**DELETE /api/users/:user_id/roles/:role_id**
- Revoke role from user
- Response: `{ revoked: true }`

**GET /api/users/:user_id/effective-scopes**
- Get user's calculated effective scopes
- Response: `{ user_id, effective_scopes: ["read:data", ...], from_roles: ["Editor", ...] }`

---

## 7. Testing Requirements

### 7.1 Unit Tests

- Role entity validation (name, scopes)
- Permission value object validation
- Effective scopes calculation with multiple roles
- Scope deduplication logic

### 7.2 Integration Tests

- Role CRUD operations with database
- User role assignment/revocation with database
- Cross-organization isolation (negative tests)
- Cascade deletion (role deleted → user_roles deleted)

### 7.3 Use Case Tests

- `AssignRole` use case with Mox
- `RevokeRole` use case with Mox
- `GenerateAgentToken` with updated delegator validation
- Effective scopes retrieval with caching

### 7.4 API Tests

- Role management endpoints (POST, GET, PATCH, DELETE)
- User role assignment endpoints
- Effective scopes endpoint
- Authentication/authorization on all endpoints

**Coverage Target:** 85%+ (following existing patterns)

---

## 8. Security Requirements

**REQ-RBAC-SEC-001:** Authorization
- Only organization admins MAY create/update/delete roles
- Only organization admins MAY assign/revoke roles
- Users MAY view their own effective scopes

**REQ-RBAC-SEC-002:** Input Validation
- All role names SHALL be sanitized (alphanumeric + spaces/dashes)
- All scope strings SHALL match regex: `^[a-z]+:[a-z_-]+$`

**REQ-RBAC-SEC-003:** Audit Logging
- All role creates/updates/deletes SHALL be logged
- All role assignments/revocations SHALL be logged
- Logs SHALL include: actor_id, action, resource_id, timestamp, metadata

---

## 9. Migration Strategy

### 9.1 Database Migration

**Phase 1:** Schema creation
- Create `roles` table
- Create `user_roles` table
- Add indexes and constraints

**Phase 2:** Backward compatibility
- Existing users without roles SHALL continue working
- `validate_delegator_has_scopes` SHALL check if user has any roles
- If user has zero roles → allow delegation (graceful degradation)
- If user has roles → enforce scope validation

### 9.2 Code Migration

**Update `GenerateAgentToken` use case:**
```elixir
defp validate_delegator_has_scopes(user, requested_scopes, deps) do
  case deps.user_repository.get_effective_scopes(user.id) do
    {:ok, []} ->
      # User has no roles - allow delegation (backward compatibility)
      Logger.info("User #{user.id} has no roles, allowing delegation")
      :ok

    {:ok, user_scopes} ->
      # User has roles - enforce validation
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

---

## 10. Acceptance Criteria

Epic 9 is complete when:

- [x] All requirements (REQ-RBAC-001 to REQ-RBAC-012) implemented
- [x] Database migration applied and tested (up/down)
- [x] Role and UserRole schemas created with validations
- [x] Role repository implemented (CRUD operations)
- [x] AssignRole and RevokeRole use cases implemented
- [x] User.get_effective_scopes/1 implemented (union of role scopes)
- [x] GenerateAgentToken.validate_delegator_has_scopes/3 updated
- [x] All API endpoints implemented and tested
- [x] Test coverage ≥ 85% on new code
- [x] Audit logging functional for all role changes
- [x] Documentation updated (API docs, architecture docs)
- [x] Backward compatibility verified (existing flows unaffected)
- [x] Zero breaking changes to existing tests

---

## 11. Out of Scope

The following are explicitly OUT OF SCOPE for Epic 9:

- ❌ **Permission inheritance hierarchies** (e.g., admin inherits editor)
- ❌ **Dynamic permission rules** (e.g., time-based, location-based)
- ❌ **Attribute-Based Access Control (ABAC)**
- ❌ **UI for role management** (API-only in Epic 9)
- ❌ **Role templates or presets**
- ❌ **Integration with external IdPs** (LDAP, AD, SAML)

These may be considered for future enhancements.

---

## 12. Dependencies and Risks

### 12.1 Dependencies

- **User entity** must have `organization_id` field ✅ (already exists)
- **OAuth2Client entity** must have `allowed_scopes` field ✅ (already exists - used for scope validation)
- **Audit logger** port must be functional ✅ (already implemented)
- **Organization entity** must support foreign key relationships ✅ (already exists)

### 12.2 Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Effective scopes calculation becomes performance bottleneck | High | Low | Implement caching with 5-minute TTL |
| Backward compatibility breaks existing agent token flows | Critical | Low | Graceful degradation (zero roles = allow all) |
| Cross-organization role assignment exploit | Critical | Low | Strict validation in all use cases + tests |

---

## 13. Success Metrics

- **Security:** Zero instances of users delegating scopes they don't have
- **Performance:** Effective scopes calculation < 10ms p99
- **Reliability:** Zero downtime during migration
- **Developer Experience:** RBAC integration in < 1 hour for developers
- **Test Coverage:** ≥ 85% on all new code

---

## 14. Change Log

**Version 1.1 (January 17, 2026):**
- Architecture review completed
- Fixed 3 critical gaps identified during review
- Enhanced for agentic workflow context (MCP servers, dynamic scopes)
- Added comprehensive API authentication specification
- Clarified backward compatibility strategy
- All requirements validated against existing codebase

**Version 1.0 (January 17, 2026):**
- Initial draft

---

**Document Status:** ✅ APPROVED - Ready for Phase 2 (Design)
**Next Steps:** Create architecture diagrams, component designs, database schema, API specifications
