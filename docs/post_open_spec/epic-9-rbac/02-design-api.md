# API Specifications
## Epic 9: Role-Based Access Control (RBAC)

**Document Version:** 1.0
**Date:** January 17, 2026
**Status:** Design Phase (Phase 2)

---

## 🌐 API Overview

Epic 9 adds **7 new REST endpoints** for role management and permission queries.

**Base URL:** `https://api.thalamus.example.com`

**Authentication:** Dual-mode (Human Admin + M2M Agent)

---

## 🔐 Authentication & Authorization

### Mode 1: Human Admin (Role Management)

**Used for:** POST/PATCH/DELETE operations on roles

**Authentication:**
```http
Authorization: Bearer {user_access_token}
```

**Authorization Requirements:**
- Token MUST have `organizations:write` scope, **OR**
- User MUST have role with `admin` permission

**Organization Context:**
- System extracts `organization_id` from token claims
- All operations scoped to user's organization

**Example Token Claims:**
```json
{
  "sub": "user_alice_123",
  "organization_id": "org_acme_corp",
  "scopes": ["organizations:write", "users:read"],
  "exp": 1705516800
}
```

---

### Mode 2: M2M Agent (Query Only)

**Used for:** GET `/api/users/:id/effective-scopes` (read-only)

**Authentication:**
```http
Authorization: Bearer {agent_access_token}
```

**Authorization Requirements:**
- Agent token MUST have valid `delegator_user_id` claim
- Agent can ONLY query effective scopes of its delegator
- Cross-user queries rejected with `403 Forbidden`

**Example Token Claims:**
```json
{
  "sub": "agent_token_xyz789",
  "organization_id": "org_acme_corp",
  "delegator_user_id": "user_alice_123",
  "agent_type": "autonomous",
  "task_id": "task_process_emails",
  "scopes": ["mcp:gmail:read", "cortex:chat"],
  "exp": 1705513200
}
```

**Use Case:**
```typescript
// Agent workflow checks delegator permissions before execution
const token = process.env.AGENT_ACCESS_TOKEN;
const response = await fetch(`https://api.thalamus.example.com/api/users/${delegatorId}/effective-scopes`, {
  headers: { 'Authorization': `Bearer ${token}` }
});
const { effective_scopes } = await response.json();

if (effective_scopes.includes('mcp:gmail:send')) {
  await executeEmailStep();
} else {
  throw new Error('Delegator lacks permission for email sending');
}
```

---

## 📋 API Endpoints

### 1. List Roles

**GET** `/api/roles`

Lists all roles in the authenticated user's organization.

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
GET /api/roles HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Response (200 OK):**
```json
{
  "roles": [
    {
      "id": "role_admin_abc123",
      "organization_id": "org_acme_corp",
      "name": "Administrator",
      "description": "Full system access",
      "scopes": ["admin", "organizations:write", "users:write", "roles:write"],
      "created_at": "2026-01-15T10:30:00Z",
      "updated_at": "2026-01-15T10:30:00Z"
    },
    {
      "id": "role_dev_xyz789",
      "organization_id": "org_acme_corp",
      "name": "Developer",
      "description": "Code and deployment access",
      "scopes": ["read:code", "write:code", "deploy:staging", "mcp:github:repos:read"],
      "created_at": "2026-01-16T14:20:00Z",
      "updated_at": "2026-01-16T14:20:00Z"
    }
  ]
}
```

**Error Responses:**
- `401 Unauthorized` - Missing or invalid token
- `403 Forbidden` - Insufficient permissions

---

### 2. Create Role

**POST** `/api/roles`

Creates a new role in the organization.

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
POST /api/roles HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
Content-Type: application/json

{
  "name": "Email Automation Manager",
  "description": "Can automate email workflows using MCP servers",
  "scopes": [
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "cortex:chat",
    "zea:read"
  ]
}
```

**Response (201 Created):**
```json
{
  "id": "role_email_def456",
  "organization_id": "org_acme_corp",
  "name": "Email Automation Manager",
  "description": "Can automate email workflows using MCP servers",
  "scopes": [
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "cortex:chat",
    "zea:read"
  ],
  "created_at": "2026-01-17T16:45:00Z",
  "updated_at": "2026-01-17T16:45:00Z"
}
```

**Error Responses:**

**422 Unprocessable Entity** (Name already exists):
```json
{
  "error": "role name must be unique within organization",
  "field": "name",
  "value": "Email Automation Manager"
}
```

**422 Unprocessable Entity** (Invalid scope format):
```json
{
  "error": "invalid_scope_format",
  "field": "scopes",
  "invalid_scopes": ["invalid scope!", "UPPERCASE:NOT:ALLOWED"]
}
```

**422 Unprocessable Entity** (Name too long):
```json
{
  "error": "name_too_long",
  "field": "name",
  "max_length": 100
}
```

---

### 3. Get Role

**GET** `/api/roles/:id`

Retrieves a single role by ID.

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
GET /api/roles/role_email_def456 HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Response (200 OK):**
```json
{
  "id": "role_email_def456",
  "organization_id": "org_acme_corp",
  "name": "Email Automation Manager",
  "description": "Can automate email workflows using MCP servers",
  "scopes": [
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "cortex:chat"
  ],
  "created_at": "2026-01-17T16:45:00Z",
  "updated_at": "2026-01-17T16:45:00Z"
}
```

**Error Responses:**
- `404 Not Found` - Role doesn't exist
- `403 Forbidden` - Role exists but belongs to different organization

---

### 4. Update Role

**PATCH** `/api/roles/:id`

Updates a role's scopes or description.

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
PATCH /api/roles/role_email_def456 HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
Content-Type: application/json

{
  "scopes": [
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "mcp:notion:pages:read",
    "cortex:chat"
  ],
  "description": "Email and Notion automation workflows"
}
```

**Response (200 OK):**
```json
{
  "id": "role_email_def456",
  "organization_id": "org_acme_corp",
  "name": "Email Automation Manager",
  "description": "Email and Notion automation workflows",
  "scopes": [
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "mcp:notion:pages:read",
    "cortex:chat"
  ],
  "created_at": "2026-01-17T16:45:00Z",
  "updated_at": "2026-01-17T17:30:00Z",
  "affected_users": 15
}
```

**Note:** `affected_users` indicates how many users had their effective scopes cache invalidated.

**Error Responses:**
- `404 Not Found` - Role doesn't exist
- `403 Forbidden` - Insufficient permissions or wrong organization
- `422 Unprocessable Entity` - Invalid scope format

---

### 5. Delete Role

**DELETE** `/api/roles/:id`

Deletes a role and all its user assignments.

**Authentication:** Mode 1 (Human Admin)

**Request (role with ≤10 users):**
```http
DELETE /api/roles/role_email_def456 HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Response (200 OK):**
```json
{
  "deleted": true,
  "affected_users": 8
}
```

**Request (role with >10 users - requires confirmation):**
```http
DELETE /api/roles/role_dev_xyz789?confirm=true HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Response (200 OK):**
```json
{
  "deleted": true,
  "affected_users": 47
}
```

**Error Responses:**

**422 Unprocessable Entity** (Confirmation required):
```json
{
  "error": "confirmation required (role has >10 users)",
  "affected_users": 47,
  "confirm_url": "/api/roles/role_dev_xyz789?confirm=true"
}
```

**404 Not Found**:
```json
{
  "error": "role not found"
}
```

---

### 6. Assign Role to User

**POST** `/api/users/:user_id/roles`

Assigns a role to a user (idempotent).

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
POST /api/users/user_bob_789/roles HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
Content-Type: application/json

{
  "role_id": "role_dev_xyz789"
}
```

**Response (201 Created):**
```json
{
  "user_id": "user_bob_789",
  "role_id": "role_dev_xyz789",
  "assigned_by": "user_alice_123",
  "assigned_at": "2026-01-17T18:00:00Z"
}
```

**Response (200 OK - Already assigned, idempotent):**
```json
{
  "user_id": "user_bob_789",
  "role_id": "role_dev_xyz789",
  "assigned_by": "user_alice_123",
  "assigned_at": "2026-01-16T10:00:00Z",
  "note": "role already assigned"
}
```

**Error Responses:**

**404 Not Found** (User doesn't exist):
```json
{
  "error": "user not found",
  "user_id": "user_bob_789"
}
```

**404 Not Found** (Role doesn't exist):
```json
{
  "error": "role not found",
  "role_id": "role_invalid"
}
```

**403 Forbidden** (Organization mismatch):
```json
{
  "error": "organization_mismatch",
  "message": "user and role must belong to same organization"
}
```

**422 Unprocessable Entity** (User not active):
```json
{
  "error": "user_not_active",
  "user_status": "suspended"
}
```

---

### 7. Revoke Role from User

**DELETE** `/api/users/:user_id/roles/:role_id`

Revokes a role from a user (idempotent).

**Authentication:** Mode 1 (Human Admin)

**Request:**
```http
DELETE /api/users/user_bob_789/roles/role_dev_xyz789 HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Response (200 OK):**
```json
{
  "revoked": true,
  "user_id": "user_bob_789",
  "role_id": "role_dev_xyz789"
}
```

**Response (200 OK - Not assigned, idempotent):**
```json
{
  "revoked": false,
  "user_id": "user_bob_789",
  "role_id": "role_dev_xyz789",
  "note": "role was not assigned to user"
}
```

**Error Responses:**
- `404 Not Found` - User or role doesn't exist
- `403 Forbidden` - Insufficient permissions

---

### 8. Get User Effective Scopes

**GET** `/api/users/:user_id/effective-scopes`

Gets the calculated effective scopes for a user (union of all role scopes).

**Authentication:** Mode 1 (Human Admin) OR Mode 2 (M2M Agent for own delegator)

**Request (Human Admin):**
```http
GET /api/users/user_bob_789/effective-scopes HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer eyJhbGci...
```

**Request (M2M Agent - querying own delegator):**
```http
GET /api/users/user_alice_123/effective-scopes HTTP/1.1
Host: api.thalamus.example.com
Authorization: Bearer {agent_token_with_delegator_user_id=user_alice_123}
```

**Response (200 OK - Cache Hit):**
```json
{
  "user_id": "user_bob_789",
  "effective_scopes": [
    "cortex:chat",
    "deploy:staging",
    "mcp:github:repos:read",
    "mcp:gmail:read",
    "mcp:gmail:send",
    "mcp:slack:write",
    "read:code",
    "write:code",
    "zea:read"
  ],
  "from_roles": [
    "Developer",
    "Email Automation Manager"
  ],
  "cached": true,
  "calculated_at": "2026-01-17T18:00:00Z"
}
```

**Response (200 OK - Cache Miss):**
```json
{
  "user_id": "user_bob_789",
  "effective_scopes": [
    "cortex:chat",
    "deploy:staging",
    "mcp:github:repos:read",
    "read:code",
    "write:code"
  ],
  "from_roles": [
    "Developer"
  ],
  "cached": false,
  "calculated_at": "2026-01-17T18:05:12Z"
}
```

**Response (200 OK - User with no roles):**
```json
{
  "user_id": "user_charlie_456",
  "effective_scopes": [],
  "from_roles": [],
  "cached": false,
  "calculated_at": "2026-01-17T18:10:00Z",
  "note": "user has no roles assigned (backward compatible mode)"
}
```

**Error Responses:**

**403 Forbidden** (Agent querying different user):
```json
{
  "error": "forbidden",
  "message": "agent can only query effective scopes of delegator",
  "agent_delegator": "user_alice_123",
  "requested_user": "user_bob_789"
}
```

**404 Not Found**:
```json
{
  "error": "user not found",
  "user_id": "user_invalid"
}
```

---

## ⚠️ Error Response Format

All error responses follow Stripe-level error format:

**Structure:**
```json
{
  "error": "error_code",
  "message": "Human-readable message",
  "field": "field_name (if applicable)",
  "doc_url": "https://docs.thalamus.example.com/errors/error_code"
}
```

**Common Error Codes:**
- `unauthorized` (401) - Missing or invalid authentication
- `forbidden` (403) - Insufficient permissions
- `not_found` (404) - Resource doesn't exist
- `organization_mismatch` (403) - Cross-organization access attempt
- `invalid_scope_format` (422) - Scope doesn't match regex
- `name_too_long` (422) - Name exceeds 100 characters
- `delegator_insufficient_permissions` (403) - User lacks scopes for delegation
- `role_already_assigned` (200) - Idempotent operation success
- `confirmation_required` (422) - Confirmation needed for >10 users

---

## 🚦 Rate Limiting

All RBAC endpoints are rate-limited:

**Limits:**
- **Human Admin operations:** 100 requests / minute per user
- **M2M Agent queries:** 1000 requests / minute per agent token
- **Role updates:** 20 requests / minute per user (stricter due to cache invalidation)

**Headers:**
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1705516800
```

**429 Response:**
```json
{
  "error": "rate_limit_exceeded",
  "message": "too many requests",
  "retry_after": 45,
  "limit": 100,
  "window": "1 minute"
}
```

---

## 🔒 Security Headers

All responses include security headers:

```http
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-XSS-Protection: 1; mode=block
```

---

## 📊 Example Workflows

### Workflow 1: Create Role and Assign to Users

```bash
# Step 1: Create role
curl -X POST https://api.thalamus.example.com/api/roles \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Data Analyst",
    "description": "Read access to data and analytics",
    "scopes": ["read:data", "read:analytics", "mcp:notion:pages:read"]
  }'
# Response: {"id": "role_analyst_abc", ...}

# Step 2: Assign to user
curl -X POST https://api.thalamus.example.com/api/users/user_dave_123/roles \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"role_id": "role_analyst_abc"}'
# Response: {"user_id": "user_dave_123", "role_id": "role_analyst_abc", ...}

# Step 3: Verify effective scopes
curl https://api.thalamus.example.com/api/users/user_dave_123/effective-scopes \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
# Response: {"effective_scopes": ["read:data", "read:analytics", "mcp:notion:pages:read"], ...}
```

---

### Workflow 2: Agent Checks Delegator Permissions

```typescript
// Agent workflow: Check permissions before executing MCP operation
async function executeEmailWorkflow(agentToken: string, delegatorId: string) {
  // Query delegator's effective scopes
  const response = await fetch(
    `https://api.thalamus.example.com/api/users/${delegatorId}/effective-scopes`,
    { headers: { 'Authorization': `Bearer ${agentToken}` } }
  );

  const { effective_scopes } = await response.json();

  // Validate delegator has required scopes
  const requiredScopes = ['mcp:gmail:read', 'mcp:gmail:send', 'cortex:chat'];
  const hasPermission = requiredScopes.every(scope => effective_scopes.includes(scope));

  if (!hasPermission) {
    throw new Error('Delegator lacks required permissions for email workflow');
  }

  // Proceed with workflow...
  await processEmails();
}
```

---

### Workflow 3: Update Role and Invalidate Caches

```bash
# Admin updates role scopes
curl -X PATCH https://api.thalamus.example.com/api/roles/role_dev_xyz789 \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "scopes": ["read:code", "write:code", "deploy:staging", "deploy:production"]
  }'
# Response includes affected_users count
# System automatically invalidates cache for all 47 users with this role
```

---

## 📈 Performance Expectations

| Endpoint | Expected p99 Latency | Notes |
|----------|----------------------|-------|
| GET /api/roles | <50ms | List all org roles |
| POST /api/roles | <100ms | Create role |
| GET /api/roles/:id | <30ms | Get single role |
| PATCH /api/roles/:id | <150ms | Update + cache invalidation |
| DELETE /api/roles/:id | <200ms | Delete + cascade |
| POST /api/users/:id/roles | <100ms | Assign + cache invalidate |
| DELETE /api/users/:id/roles/:role_id | <100ms | Revoke + cache invalidate |
| GET /api/users/:id/effective-scopes (cached) | <5ms | Cache hit |
| GET /api/users/:id/effective-scopes (uncached) | <20ms | DB query + calculation |

---

## ✅ API Design Checklist

- [x] RESTful resource naming
- [x] Idempotent operations (assign/revoke)
- [x] Stripe-level error responses
- [x] Comprehensive error codes
- [x] Rate limiting
- [x] Security headers
- [x] Multi-tenant isolation
- [x] Dual authentication modes
- [x] Backward compatibility
- [x] Performance targets documented

---

**Document Status:** ✅ Complete
**Phase 2 (Design):** ✅ All documents complete
**Next:** [Phase 3 - Tasks](03-tasks.md) - Implementation task breakdown
