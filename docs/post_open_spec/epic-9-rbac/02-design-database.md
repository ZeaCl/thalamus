# Database Design
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.0
**Date:** January 17, 2026
**Status:** Design Phase (Phase 2)

---

## 📊 Database Schema Overview

```
┌──────────────────┐
│   organizations  │
│                  │
│  • id (PK)       │
│  • name          │
│  • status        │
└────────┬─────────┘
         │ 1
         │
         │ N
┌────────▼─────────┐
│     roles        │◄───────────┐
│                  │            │
│  • id (PK)       │            │
│  • organization_id (FK)       │
│  • name (UK)     │            │
│  • description   │            │
│  • scopes[]      │            │
│  • created_at    │            │
│  • updated_at    │            │
└────────┬─────────┘            │
         │ 1                    │
         │                      │
         │ N                    │
┌────────▼─────────┐            │
│   user_roles     │            │
│  (JOIN TABLE)    │            │
│                  │            │
│  • id (PK)       │            │
│  • user_id (FK)  │            │
│  • role_id (FK) ─┘            │
│  • assigned_by   │
│  • assigned_at   │
└────────┬─────────┘
         │ N
         │
         │ 1
┌────────▼─────────┐
│      users       │
│                  │
│  • id (PK)       │
│  • organization_id (FK)
│  • email         │
│  • password_hash │
│  • status        │
└──────────────────┘
```

---

## 🗄️ Table Schemas

### Table: `roles`

```sql
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  scopes TEXT[] DEFAULT '{}',
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT roles_name_length CHECK (char_length(name) >= 1 AND char_length(name) <= 100),
  CONSTRAINT roles_description_length CHECK (
    description IS NULL OR char_length(description) <= 500
  )
);
```

**Column Details:**
- `id`: Primary key, auto-generated UUID
- `organization_id`: Foreign key to organizations (CASCADE delete)
- `name`: Role name (1-100 chars), unique within organization
- `description`: Optional description (max 500 chars)
- `scopes`: Array of scope strings (validated format in application)
- `inserted_at`: Creation timestamp
- `updated_at`: Last modification timestamp

---

### Table: `user_roles`

```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT user_roles_unique_assignment UNIQUE (user_id, role_id)
);
```

**Column Details:**
- `id`: Primary key, auto-generated UUID
- `user_id`: Foreign key to users (CASCADE delete)
- `role_id`: Foreign key to roles (CASCADE delete)
- `assigned_by`: Optional user ID who performed assignment (SET NULL on delete)
- `assigned_at`: When the role was assigned
- `inserted_at`: Record creation timestamp

**Unique Constraint:**
- `(user_id, role_id)` - Prevents duplicate role assignments to same user

---

## 📇 Indexes

### Primary Keys (Automatic)
```sql
-- Automatically created by PRIMARY KEY constraint
CREATE UNIQUE INDEX roles_pkey ON roles(id);
CREATE UNIQUE INDEX user_roles_pkey ON user_roles(id);
```

### 1. Unique Index: Role Name within Organization

```sql
CREATE UNIQUE INDEX roles_organization_id_name_index
ON roles(organization_id, name);
```

**Purpose:** Ensures role names are unique within each organization

**Use Cases:**
- Prevent duplicate role names (e.g., two "Admin" roles in same org)
- Fast lookup by `(organization_id, name)`

**Query Example:**
```sql
SELECT * FROM roles
WHERE organization_id = 'org_abc123'
AND name = 'Developer';
```

**Performance:** O(log N), composite B-tree index

---

### 2. Index: Organization ID (List Roles)

```sql
CREATE INDEX roles_organization_id_index
ON roles(organization_id);
```

**Purpose:** Fast retrieval of all roles for an organization

**Use Cases:**
- List roles in admin dashboard
- Organization deletion (CASCADE with many roles)

**Query Example:**
```sql
SELECT * FROM roles
WHERE organization_id = 'org_abc123'
ORDER BY name;
```

**Performance:** O(log N) lookup, sequential scan for matching org

---

### 3. Unique Index: User-Role Assignment

```sql
CREATE UNIQUE INDEX user_roles_user_id_role_id_index
ON user_roles(user_id, role_id);
```

**Purpose:** Prevent duplicate assignments, fast lookup

**Use Cases:**
- Check if user already has role (before insert)
- Revoke specific role from user
- Idempotent assignment operations

**Query Example:**
```sql
SELECT * FROM user_roles
WHERE user_id = 'user_123' AND role_id = 'role_456';
```

**Performance:** O(log N), composite unique index

---

### 4. Index: User ID (Get User Roles)

```sql
CREATE INDEX user_roles_user_id_index
ON user_roles(user_id);
```

**Purpose:** Fast retrieval of all roles for a user

**Use Cases:**
- Calculate effective scopes for user
- Display user's assigned roles
- User deletion (CASCADE)

**Query Example:**
```sql
SELECT r.* FROM roles r
JOIN user_roles ur ON ur.role_id = r.id
WHERE ur.user_id = 'user_123';
```

**Performance:** O(log N) + join cost

---

### 5. Index: Role ID (Get Users with Role)

```sql
CREATE INDEX user_roles_role_id_index
ON user_roles(role_id);
```

**Purpose:** Fast retrieval of all users with a specific role

**Use Cases:**
- Update role scopes → invalidate cache for all affected users
- Delete role → cascade to user_roles
- Count users with role

**Query Example:**
```sql
SELECT user_id FROM user_roles
WHERE role_id = 'role_456';
```

**Performance:** O(log N)

---

## 🗓️ Migration File

**File:** `priv/repo/migrations/20260117_add_rbac_tables.exs`

```elixir
defmodule Thalamus.Repo.Migrations.AddRbacTables do
  use Ecto.Migration

  def up do
    # Create roles table
    create table(:roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :string, size: 100, null: false
      add :description, :text
      add :scopes, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    # Create user_roles join table
    create table(:user_roles, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false
      add :assigned_by, references(:users, type: :uuid, on_delete: :nilify_all)
      add :assigned_at, :utc_datetime, null: false, default: fragment("NOW()")

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Indexes for roles table
    create unique_index(:roles, [:organization_id, :name],
             name: :roles_organization_id_name_index
           )

    create index(:roles, [:organization_id], name: :roles_organization_id_index)

    # Indexes for user_roles table
    create unique_index(:user_roles, [:user_id, :role_id],
             name: :user_roles_user_id_role_id_index
           )

    create index(:user_roles, [:user_id], name: :user_roles_user_id_index)
    create index(:user_roles, [:role_id], name: :user_roles_role_id_index)

    # Check constraints
    execute("""
      ALTER TABLE roles
      ADD CONSTRAINT roles_name_length
      CHECK (char_length(name) >= 1 AND char_length(name) <= 100)
    """)

    execute("""
      ALTER TABLE roles
      ADD CONSTRAINT roles_description_length
      CHECK (description IS NULL OR char_length(description) <= 500)
    """)
  end

  def down do
    # Drop constraints
    execute("ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_description_length")
    execute("ALTER TABLE roles DROP CONSTRAINT IF EXISTS roles_name_length")

    # Drop indexes (automatically dropped with tables, but explicit for clarity)
    drop_if_exists index(:user_roles, [:role_id], name: :user_roles_role_id_index)
    drop_if_exists index(:user_roles, [:user_id], name: :user_roles_user_id_index)

    drop_if_exists unique_index(:user_roles, [:user_id, :role_id],
                     name: :user_roles_user_id_role_id_index
                   )

    drop_if_exists index(:roles, [:organization_id], name: :roles_organization_id_index)

    drop_if_exists unique_index(:roles, [:organization_id, :name],
                     name: :roles_organization_id_name_index
                   )

    # Drop tables (CASCADE handled by foreign keys)
    drop table(:user_roles)
    drop table(:roles)
  end
end
```

---

## 🔐 Security & Multi-Tenancy

### Foreign Key Constraints

```sql
-- Organization deleted → All roles deleted → All user_roles deleted
roles.organization_id → organizations.id (ON DELETE CASCADE)

-- User deleted → All their role assignments deleted
user_roles.user_id → users.id (ON DELETE CASCADE)

-- Role deleted → All assignments of that role deleted
user_roles.role_id → roles.id (ON DELETE CASCADE)

-- Admin who assigned role deleted → assigned_by set to NULL (audit trail preserved)
user_roles.assigned_by → users.id (ON DELETE SET NULL)
```

### Query-Level Isolation

**ALL queries MUST filter by organization_id:**

```sql
-- ❌ WRONG - Cross-organization data leak
SELECT * FROM roles WHERE name = 'Admin';

-- ✅ CORRECT - Scoped to organization
SELECT * FROM roles
WHERE organization_id = ? AND name = 'Admin';
```

**Repository pattern enforces this automatically.**

---

## 📈 Data Examples

### Example 1: Simple Role

```sql
INSERT INTO roles (id, organization_id, name, description, scopes, inserted_at, updated_at)
VALUES (
  'role_developer_abc123',
  'org_acme_corp',
  'Developer',
  'Full access to code repositories and CI/CD',
  ARRAY['read:code', 'write:code', 'deploy:staging'],
  NOW(),
  NOW()
);
```

### Example 2: MCP-Aware Role

```sql
INSERT INTO roles (id, organization_id, name, description, scopes, inserted_at, updated_at)
VALUES (
  'role_email_automation_xyz',
  'org_acme_corp',
  'Email Automation Manager',
  'Can automate email workflows using MCP servers',
  ARRAY[
    'mcp:gmail:read',
    'mcp:gmail:send',
    'mcp:slack:write',
    'cortex:chat',
    'zea:read'
  ],
  NOW(),
  NOW()
);
```

### Example 3: User Role Assignment

```sql
INSERT INTO user_roles (id, user_id, role_id, assigned_by, assigned_at, inserted_at)
VALUES (
  gen_random_uuid(),
  'user_alice_123',
  'role_developer_abc123',
  'user_admin_456',  -- Admin who assigned the role
  NOW(),
  NOW()
);
```

### Example 4: Multiple Roles per User

```sql
-- User has 3 roles: Developer, Email Automation Manager, Reader
INSERT INTO user_roles (user_id, role_id, assigned_by, assigned_at, inserted_at) VALUES
  ('user_bob_789', 'role_developer_abc123', 'user_admin_456', NOW(), NOW()),
  ('user_bob_789', 'role_email_automation_xyz', 'user_admin_456', NOW(), NOW()),
  ('user_bob_789', 'role_reader_basic', 'user_admin_456', NOW(), NOW());

-- Effective scopes = union of all 3 roles
```

---

## 🔍 Query Patterns

### 1. Get User's Effective Scopes

```sql
-- Method 1: Join and aggregate
SELECT ARRAY_AGG(DISTINCT scope) AS effective_scopes
FROM (
  SELECT unnest(r.scopes) AS scope
  FROM roles r
  JOIN user_roles ur ON ur.role_id = r.id
  WHERE ur.user_id = 'user_alice_123'
) AS all_scopes;

-- Result: ['read:code', 'write:code', 'deploy:staging', 'mcp:gmail:read', ...]
```

### 2. List Users with a Specific Role

```sql
SELECT u.id, u.email, u.name, ur.assigned_at
FROM users u
JOIN user_roles ur ON ur.user_id = u.id
WHERE ur.role_id = 'role_developer_abc123'
ORDER BY ur.assigned_at DESC;
```

### 3. Find Roles with Specific Scope

```sql
SELECT id, name, scopes
FROM roles
WHERE organization_id = 'org_acme_corp'
AND 'mcp:gmail:send' = ANY(scopes);
```

### 4. Count Role Assignments

```sql
SELECT
  r.name,
  COUNT(ur.user_id) AS user_count
FROM roles r
LEFT JOIN user_roles ur ON ur.role_id = r.id
WHERE r.organization_id = 'org_acme_corp'
GROUP BY r.id, r.name
ORDER BY user_count DESC;
```

---

## 📊 Performance Characteristics

### Index Selectivity

| Index | Selectivity | Cardinality (1M users) |
|-------|-------------|------------------------|
| roles(organization_id, name) | Very High | ~100-1000 roles |
| user_roles(user_id, role_id) | Very High | ~5M assignments (avg 5 roles/user) |
| user_roles(user_id) | High | ~5M |
| user_roles(role_id) | Medium | ~5M |

### Query Performance Estimates

| Operation | Complexity | Estimated Time (1M users) |
|-----------|------------|---------------------------|
| Find role by (org, name) | O(log N) | <1ms (unique index) |
| List org roles | O(log N + K) | <5ms (K=100 roles) |
| Get user roles | O(log N + K) | <5ms (K=5 roles avg) |
| Calculate effective scopes | O(log N + K*M) | <10ms (K=5 roles, M=10 scopes/role) |
| Assign role | O(log N) | <5ms (insert + index update) |
| Update role scopes | O(log N + U) | <50ms (update + U users cache invalidation) |

---

## 🧪 Test Data Setup

### Seed Script for Development

```elixir
# priv/repo/seeds/rbac_seed.exs

alias Thalamus.Domain.Entities.Role
alias Thalamus.Infrastructure.Repositories.PostgresqlRoleRepository

repo = PostgresqlRoleRepository

# Organization (assume exists)
org_id = "org_test_123"

# Create roles
{:ok, admin_role} = Role.new(%{
  organization_id: org_id,
  name: "Administrator",
  description: "Full system access",
  scopes: ["admin", "organizations:write", "users:write", "roles:write"]
})

{:ok, _} = repo.save(admin_role)

{:ok, dev_role} = Role.new(%{
  organization_id: org_id,
  name: "Developer",
  description: "Code and deployment access",
  scopes: ["read:code", "write:code", "deploy:staging", "mcp:github:repos:read"]
})

{:ok, _} = repo.save(dev_role)

{:ok, email_role} = Role.new(%{
  organization_id: org_id,
  name: "Email Automation",
  description: "Email workflow automation",
  scopes: ["mcp:gmail:read", "mcp:gmail:send", "mcp:slack:write", "cortex:chat"]
})

{:ok, _} = repo.save(email_role)

IO.puts("✅ Created 3 test roles")
```

---

## 🔄 Migration Strategy

### Phase 1: Schema Creation (Epic 9 implementation)

```bash
# Run migration
mix ecto.migrate

# Verify tables created
psql -d thalamus_dev -c "\\dt roles"
psql -d thalamus_dev -c "\\dt user_roles"

# Verify indexes
psql -d thalamus_dev -c "\\di roles*"
psql -d thalamus_dev -c "\\di user_roles*"
```

### Phase 2: Backward Compatibility Validation

```sql
-- Verify existing users still work (no roles assigned)
SELECT id, email FROM users WHERE id NOT IN (SELECT DISTINCT user_id FROM user_roles);

-- These users should still be able to generate agent tokens
-- (graceful degradation: no roles = allow delegation)
```

### Phase 3: Gradual Rollout

1. **Week 1:** Create roles for organizations
2. **Week 2:** Assign roles to subset of users (10%)
3. **Week 3:** Monitor logs for `delegator_insufficient_permissions` errors
4. **Week 4:** Expand to 50% of users
5. **Week 5:** Full rollout (100% users have roles)

---

## 📝 Database Maintenance

### Cleanup Orphaned Records

```sql
-- Find user_roles with non-existent users (shouldn't happen due to FK CASCADE)
SELECT ur.id FROM user_roles ur
LEFT JOIN users u ON u.id = ur.user_id
WHERE u.id IS NULL;

-- Find user_roles with non-existent roles (shouldn't happen due to FK CASCADE)
SELECT ur.id FROM user_roles ur
LEFT JOIN roles r ON r.id = ur.role_id
WHERE r.id IS NULL;
```

### Index Maintenance

```sql
-- Reindex if performance degrades (rarely needed with Postgres)
REINDEX INDEX roles_organization_id_name_index;
REINDEX INDEX user_roles_user_id_role_id_index;

-- Analyze for query planner optimization
ANALYZE roles;
ANALYZE user_roles;
```

### Table Statistics

```sql
-- Table sizes
SELECT
  pg_size_pretty(pg_total_relation_size('roles')) AS roles_size,
  pg_size_pretty(pg_total_relation_size('user_roles')) AS user_roles_size;

-- Row counts
SELECT
  (SELECT COUNT(*) FROM roles) AS roles_count,
  (SELECT COUNT(*) FROM user_roles) AS user_roles_count;
```

---

## ✅ Migration Checklist

Before running migration in production:

- [ ] Review migration file for syntax errors
- [ ] Test migration up/down in development
- [ ] Test migration up/down in staging
- [ ] Verify all indexes created
- [ ] Verify all constraints created
- [ ] Test backward compatibility (users without roles)
- [ ] Benchmark query performance with sample data
- [ ] Plan rollback strategy
- [ ] Schedule maintenance window (if needed)
- [ ] Backup database before migration

---

**Document Status:** ✅ Complete
**Next:** [02-design-api.md](02-design-api.md) - REST API specifications
