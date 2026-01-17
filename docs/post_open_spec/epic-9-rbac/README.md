# Epic 9: Role-Based Access Control (RBAC)

**Status:** ✅ All Phases Complete - Ready for Implementation
**Created:** January 17, 2026
**Updated:** January 17, 2026
**Epic Number:** 9 of 9
**Priority:** High
**Estimated Effort:** 80-100 hours (2-3 weeks, 1 developer)

---

## 🎯 Epic Overview

Implement **Role-Based Access Control (RBAC)** to enable fine-grained authorization for agent token generation. This epic resolves the TODO in `GenerateAgentToken` use case (lines 139-166) by validating that delegator users have permission to delegate the requested scopes.

### Problem Statement

Currently, users can delegate any scopes that the OAuth2 client allows, regardless of their personal permissions:

```elixir
# Current implementation (simplified)
defp validate_delegator_has_scopes(_user, _requested_scopes, _deps) do
  Logger.warning("Delegator scope validation is simplified...")
  :ok  # Allows all delegations ⚠️
end
```

**Security Gap:** User B with scope `"read:data"` can generate agent token with scope `"write:data"` if the client allows it.

### Solution

Implement RBAC with:
- **Roles:** Named collections of scopes (e.g., "Document Editor")
- **User role assignments:** Many-to-many relationship
- **Effective scopes:** Union of all assigned role scopes
- **Validation:** `requested_scopes ⊆ user.effective_scopes`

---

## 📚 OpenSpec Documents

Following the 3-phase OpenSpec workflow:

### Phase 1: Requirements ✅ APPROVED
- [**01-requirements.md**](./01-requirements.md) - EARS format requirements (v1.1)
  - 5 user stories (US-RBAC-001 to US-RBAC-005)
  - 12 functional requirements (REQ-RBAC-001 to REQ-RBAC-012)
  - 5 non-functional requirements
  - API specifications (includes authentication modes)
  - Testing requirements
  - Migration strategy
  - **Enhancements in v1.1:**
    - MCP-aware scope validation (dynamic, task-specific scopes)
    - Layered security model (4 validation layers)
    - Dual authentication modes (Human Admin + M2M Agent)
    - Backward compatibility guaranteed

**Status:** ✅ Approved - Validated against agentic workflow requirements

### Phase 2: Design ✅ COMPLETE
- [x] [02-design-index.md](./02-design-index.md) - Navigation and design decisions
- [x] [02-design-architecture.md](./02-design-architecture.md) - Diagrams and flows (579 lines)
- [x] [02-design-components.md](./02-design-components.md) - Production-ready code (1,234 lines)
- [x] [02-design-database.md](./02-design-database.md) - Migrations and schema (668 lines)
- [x] [02-design-api.md](./02-design-api.md) - REST API specifications (770 lines)

**Status:** ✅ Complete - All 5 design documents created with full specifications

### Phase 3: Tasks ✅ COMPLETE
- [x] [03-tasks.md](./03-tasks.md) - 37 implementation tasks organized by layer

**Status:** ✅ Complete - Ready for implementation sprint planning

---

## 🔗 Integration Points

### Domain Layer (New Code)
- `Role` entity - Domain representation of role
- `Permission` value object - Individual scope permission

### Infrastructure Layer (New Code)
- Migration: `roles` table
- Migration: `user_roles` join table
- `RoleSchema` - Ecto schema for roles
- `UserRoleSchema` - Ecto schema for user_roles
- `PostgresqlRoleRepository` - Repository implementation

### Application Layer (New + Updated)
- **New:** `AssignRole` use case
- **New:** `RevokeRole` use case
- **New:** `GetEffectiveScopes` use case (or repository method)
- **Updated:** `GenerateAgentToken.validate_delegator_has_scopes/3` ⚠️

### Presentation Layer (New Code)
- `RoleController` - CRUD operations
- `UserRoleController` - Assignment/revocation endpoints
- Router: `/api/roles`, `/api/users/:id/roles`, `/api/users/:id/effective-scopes`

---

## 📊 Key Requirements Highlights

### Functional

**Role Management:**
- Create/update/delete roles with scopes
- Organization-scoped (isolated per tenant)
- Unique role names within organization

**User Role Assignment:**
- Assign multiple roles to user
- Effective scopes = union of all role scopes
- Immediate cache invalidation on changes

**Delegation Validation:**
- **Core:** Validate `requested_scopes ⊆ user.effective_scopes`
- Backward compatible: Users with zero roles → allow delegation

### Non-Functional

- **Performance:** Effective scopes calculation < 10ms p99
- **Scalability:** Up to 100 roles/org, 50 roles/user
- **Security:** Audit logging for all role changes
- **Backward Compatibility:** Zero breaking changes

---

## 🧪 Testing Strategy

### Coverage Targets
- Domain: 100% (Role entity, Permission VO)
- Application: 90% (use cases with Mox)
- Infrastructure: 85% (repositories with DB)
- Web: 85% (controllers with ConnCase)

### Test Types
- Unit tests (domain logic)
- Integration tests (database operations)
- Use case tests (with Mox for dependencies)
- API tests (endpoint behavior)
- Multi-tenancy tests (cross-org isolation)
- Backward compatibility tests (existing flows)

---

## 📋 Implementation Checklist

### Phase 1: Requirements ✅ COMPLETE
- [x] Write requirements document (EARS format)
- [x] Define user stories (5 stories)
- [x] Define functional requirements (12 requirements)
- [x] Define non-functional requirements (5 requirements)
- [x] Design data model (Role, UserRole)
- [x] Define API endpoints
- [x] Define testing strategy
- [x] Define migration strategy
- [x] Architecture review and gap analysis
- [x] Fix critical gaps (scope validation, auth modes)
- [x] **Requirements approved** ✅

### Phase 2: Design ✅ COMPLETE
- [x] Create architecture diagrams (Mermaid)
- [x] Design component interactions
- [x] Write database migration code
- [x] Design repository interfaces
- [x] Design use case flows
- [x] Design API request/response formats
- [x] Review and approve design

### Phase 3: Tasks ✅ COMPLETE
- [x] Break down implementation into 37 tasks
- [x] Assign effort estimates (80-100 hours total)
- [x] Define acceptance criteria per task
- [x] Define task dependencies (dependency graph)
- [x] Organize into 4 sprints
- [x] Review and approve task plan

---

## 🚦 Current Status

**Phase:** ✅ All Phases Complete
**Progress:** Phase 1 (Requirements) ✅ | Phase 2 (Design) ✅ | Phase 3 (Tasks) ✅

**Phase 1 Summary:**
- ✅ Requirements document v1.1 approved
- ✅ All 3 critical gaps resolved
- ✅ Validated against agentic workflow context
- ✅ Backward compatibility guaranteed
- ✅ Security model defined (4 validation layers)

**Phase 2 Summary:**
- ✅ 5 design documents created (3,566 total lines)
- ✅ Complete architecture diagrams (ER, sequence, component)
- ✅ Production-ready code for all layers
- ✅ Database migration with indexes and constraints
- ✅ REST API specifications with 8 endpoints

**Phase 3 Summary:**
- ✅ 37 discrete tasks organized by layer
- ✅ 4 sprints planned (2-3 weeks timeline)
- ✅ Task dependencies mapped (Mermaid graph)
- ✅ Acceptance criteria defined for each task
- ✅ Test coverage targets specified

**Next Action:** Begin Sprint 1 implementation (Domain + Infrastructure layers)

---

## 🔮 Future Enhancements (Post-Epic 9)

Explicitly out of scope but may be considered later:

- Permission inheritance hierarchies
- Attribute-Based Access Control (ABAC)
- Time-based or location-based permissions
- Role templates/presets
- LiveView UI for role management
- Integration with external IdPs (LDAP, SAML)

---

## 🔗 Related Documentation

**Current Implementation:**
- [GenerateAgentToken use case](../../lib/thalamus/application/use_cases/generate_agent_token.ex) (lines 139-166 - TODO)
- [User entity](../../lib/thalamus/domain/entities/user.ex) (no roles field yet)
- [Epics 1-8 documentation](../post_open_spec/)

**Architecture:**
- [Clean Architecture Guide](../../CLAUDE.md#architecture)
- [SOLID Principles](../../CLAUDE.md#solid-principles-strictly-enforced)

**Testing:**
- [Testing Strategy](../post_open_spec/IMPLEMENTATION_CONTEXT.md#testing-requirements)

---

**Ready for:** ✅ Implementation - Sprint 1 🚀
**Next Steps:**
1. Create GitHub issues for Sprint 1 tasks (9 tasks)
2. Begin Domain layer implementation (Permission VO + Role Entity)
3. Set up database migration
4. Implement PostgresqlRoleRepository
