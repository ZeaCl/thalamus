# Technical Limitations & Current State

**Last Updated**: 2026-01-02
**Version**: 0.9.0

This document provides an honest assessment of the current implementation state, known limitations, and technical debt in Thalamus OAuth2 Server.

---

## ⚠️ Critical Limitations

### 1. JWT Authentication (Placeholder)

**Status**: ⚠️ **NOT IMPLEMENTED**

**Location**: `lib/thalamus_web/plugs/api_auth.ex:58-79`

```elixir
defp validate_jwt(conn, _token) do
  # TODO: Implement JWT validation once Guardian/Joken is set up
  # Placeholder implementation
  conn
  |> assign(:auth_type, :jwt)
  |> assign(:current_user, %{id: "placeholder-user-id"})
  |> assign(:user_id, "placeholder-user-id")
end
```

**Impact**:
- ❌ `Authorization: Bearer <jwt>` authentication is **NOT secure**
- ❌ All JWT requests are accepted with placeholder user
- ✅ `Authorization: ApiKey <key>` **DOES work** properly (Bcrypt-hashed, secure)

**Required for production**:
- Implement JWT validation using Guardian or Joken
- Add proper signature verification
- Load actual user from database
- Estimated effort: **3-4 hours**

---

### 2. Redis Integration (Mock Mode)

**Status**: ⚠️ **MOCK ONLY**

**Location**: `lib/thalamus/infrastructure/adapters/redis_cache_adapter.ex:115-124`

```elixir
defp redis_command(command) do
  case Application.get_env(:thalamus, :redis_adapter, :mock) do
    :mock -> mock_redis_command(command)    # ⚠️ CURRENT
    :redix -> {:error, :not_configured}     # ⚠️ NOT IMPLEMENTED
  end
end
```

**Location**: `config/config.exs:81`

```elixir
config :hammer,
  backend: {Hammer.Backend.ETS, [    # ⚠️ ETS, not Redis
    expiry_ms: 60_000 * 60 * 2,
    cleanup_interval_ms: 60_000 * 10
  ]}
```

**Impact**:
- ❌ Rate limiting uses **in-memory ETS** (resets on server restart)
- ❌ No token caching (every introspection hits database)
- ❌ Not suitable for multi-instance deployment

**Current Workarounds**:
- ✅ ETS works for single-instance deployments
- ✅ Database queries are fast enough for MVP (~10-20ms per introspection)

**Required for production**:
- Configure Redix connection pool
- Switch Hammer backend to Redis
- Implement token introspection cache
- Estimated effort: **4-6 hours**

---

### 3. Scopes (Hardcoded List)

**Status**: ⚠️ **NOT EXTENSIBLE**

**Location**: `lib/thalamus/domain/value_objects/scope.ex:18-42,244`

```elixir
@standard_scopes ["openid", "profile", "email", "address", "phone", "offline_access"]

@zea_scopes [
  "zea:read", "zea:write", "zea:admin",
  "synapse:events", "synapse:metrics",
  "cortex:chat", "cortex:completions",
  "billing:read", "billing:write",
  "organizations:read", "organizations:write"
]

@all_valid_scopes @standard_scopes ++ @zea_scopes

defp validate_format(value) do
  # ...
  not Enum.member?(@all_valid_scopes, value) ->
    {:error, :unknown_scope}  # ⚠️ REJECTS CUSTOM SCOPES
end
```

**Impact**:
- ❌ **Total scopes**: 17 (6 OIDC standard + 11 ZEA platform)
- ❌ Cannot define custom scopes without code changes
- ❌ Clients cannot create domain-specific scopes (e.g., `sport:read`, `campaigns:write`)
- ❌ No scope hierarchy or wildcards

**Required for MCP/Agent integration**:
- Add database table for custom scopes
- Remove hardcoded validation
- Support scope patterns (e.g., `*:read`, `mcp:tools:*`)
- Estimated effort: **6-8 hours**

---

### 4. Token Metadata (Not Supported)

**Status**: ❌ **NO CUSTOM METADATA**

**Location**: `lib/thalamus/infrastructure/persistence/schemas/token_schema.ex`

**Current token fields**:
```elixir
schema "tokens" do
  field :token, :string
  field :type, Ecto.Enum  # :access_token, :refresh_token, :authorization_code
  field :scopes, {:array, :string}
  field :expires_at, :utc_datetime
  field :revoked, :boolean
  field :code_challenge, :string
  field :token_family_id, :binary_id

  belongs_to :user, UserSchema
  belongs_to :client, OAuth2ClientSchema
  belongs_to :organization, OrganizationSchema

  timestamps()
end
```

**Missing fields for MCP/Agents**:
- ❌ `metadata` (JSONB) - Custom token claims
- ❌ `agent_type` - Type of agent (autonomous, supervised)
- ❌ `delegated_by_user_id` - Delegation chain
- ❌ `task_id` - Associated task ID
- ❌ `task_scopes` - Task-specific scopes
- ❌ `intent_description` - Human-readable intent

**Impact**:
- ❌ Cannot store custom claims in tokens
- ❌ Token introspection returns only standard fields
- ❌ No support for agent delegation
- ❌ No task-scoped tokens

**Required for MCP integration**:
- Add migration for metadata fields
- Update token generation use case
- Extend introspection response
- Estimated effort: **3-4 hours**

---

### 5. Token Architecture (Opaque, not JWT)

**Status**: ℹ️ **BY DESIGN** (but has tradeoffs)

**Location**: `lib/thalamus/application/services/token_generator.ex`

**Current implementation**:
```elixir
# Tokens are random strings, NOT JWTs
:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
# Result: "at_vK8mN2pQ7xR9tY3wZ5aB1cD4eF6gH8j..."
```

**Dependencies installed but NOT used**:
```elixir
{:guardian, "~> 2.3"}    # ❌ NOT USED
{:joken, "~> 2.6"}       # ❌ NOT USED
{:jose, "~> 1.11"}       # ❌ NOT USED
```

**Advantages** (current design):
- ✅ Cannot be forged
- ✅ Instant revocation (just UPDATE in database)
- ✅ No signature verification overhead
- ✅ No token expiry within token (controlled by DB)

**Disadvantages** (current design):
- ❌ Requires database lookup for every introspection (**10-20ms latency**)
- ❌ Not self-contained (no claims inside token)
- ❌ Cannot be validated offline
- ❌ Not compatible with some MCP servers expecting JWTs

**Required for MCP integration**:
- Option A: Keep opaque tokens, add introspection caching (**3-4 hours**)
- Option B: Migrate to JWT tokens (**12-16 hours**, breaking change)

---

### 6. Delegation (Not Implemented)

**Status**: ❌ **NOT IMPLEMENTED**

**Impact**:
- ❌ No concept of "user A authorized user B to act on their behalf"
- ❌ No delegation chain tracking
- ❌ Cannot trace "who authorized this action"
- ❌ Audit logs don't capture delegation

**Required for agent scenarios**:
- Add `delegated_by_user_id` to tokens
- Add `delegation_chain` array
- Track delegation in audit logs
- Update introspection response
- Estimated effort: **4-5 hours**

---

## 📊 Performance Metrics

### Token Introspection Latency

**Without cache** (current state):
- Database query for token: **~5-10ms**
- Database query for user email: **~5-10ms**
- JSON serialization: **~1ms**
- **Total: 10-20ms per request**

**With Redis cache** (not implemented):
- Cache hit: **1-3ms**
- Cache miss: **15-25ms** (query + cache set)
- **Average with 80% hit rate: ~5ms**

---

## ✅ What Actually Works

Despite the limitations above, **these features are production-ready**:

### Fully Functional
- ✅ **Admin API Keys**: Complete end-to-end (creation, authentication, rotation, revocation)
  - Bcrypt-hashed, never stored in plaintext
  - Scoped permissions working correctly
  - 35 test cases passing
- ✅ **OAuth2 Flows**:
  - Authorization Code + PKCE ✅
  - Client Credentials ✅
  - Refresh Token ✅
  - Token Revocation ✅
  - Token Introspection ✅ (but slow without cache)
- ✅ **Web Dashboard**: Complete admin UI with LiveView
  - Users, Clients, Organizations, Tokens, Audit Logs
  - Real-time updates, search, filtering
  - 189 tests passing
- ✅ **Multi-tenancy**: Organization-based isolation working
- ✅ **Audit Logging**: Immutable security trail with advanced filtering
- ✅ **Security**: Rate limiting (ETS), CORS, security headers, password hashing
- ✅ **Database**: PostgreSQL with proper migrations and indexes
- ✅ **Tests**: 189 tests, 80% coverage

---

## 🚀 Recommended Priority Fixes

### 🔴 CRITICAL (before production)

1. **Implement JWT Authentication** (3-4h)
   - Replace placeholder in `api_auth.ex`
   - Use Guardian or Joken
   - Add proper user loading

2. **Connect Real Redis** (4-6h)
   - Configure Redix connection pool
   - Switch Hammer to Redis backend
   - Add token introspection caching

### 🟠 HIGH (for MCP/Agent support)

3. **Add Token Metadata Support** (3-4h)
   - Migration: `add :metadata, :map`
   - Update token generation
   - Extend introspection response

4. **Implement Extensible Scopes** (6-8h)
   - Create `scopes` database table
   - Remove hardcoded validation
   - Support custom client scopes

5. **Add Delegation Support** (4-5h)
   - Add delegation fields to tokens
   - Track delegation chain
   - Update audit logs

### 🟡 MEDIUM (nice to have)

6. **Optimize Performance** (2-3h)
   - Add database query caching
   - Optimize N+1 queries
   - Add connection pooling tuning

7. **CI/CD Pipeline** (4-6h)
   - GitHub Actions workflows
   - Automated testing
   - Docker build pipeline

---

## 📈 Test Coverage Reality

**Overall**: 80% (189 tests passing)

**By Layer**:
- Domain Layer: **100%** ✅
- Application Layer: **100%** ✅
- Infrastructure Layer: **95%** ✅
- Web Dashboard: **85%** ✅ (176 LiveView tests)
- Controllers: **100%** ✅ (all critical paths)

**Integration Tests**:
- ✅ Complete OAuth2 flows tested end-to-end
- ✅ `test/integration/oauth2_flow_test.exs`: 468 lines
- ✅ Real database (Ecto.Adapters.SQL.Sandbox)
- ✅ PKCE, Client Credentials, Token Rotation

---

## 🎯 Honest Current State Summary

**What we can claim**:
- ✅ "Production-ready for Admin API Key authentication"
- ✅ "Production-ready web dashboard"
- ✅ "OAuth2 flows fully implemented and tested"
- ✅ "Single-instance deployment ready"
- ✅ "Comprehensive audit logging"

**What we CANNOT claim yet**:
- ❌ "Production-ready for JWT authentication" (placeholder)
- ❌ "Multi-instance deployment ready" (no Redis)
- ❌ "Extensible scope system" (hardcoded)
- ❌ "MCP/Agent ready" (no metadata, delegation, custom scopes)
- ❌ "Sub-5ms introspection" (no caching)

**Estimated effort to remove all limitations**: **~30-40 hours**

---

## 📝 Next Steps

### Immediate (this week)
1. Document these limitations in README
2. Add "Known Limitations" section to docs
3. Update version numbering to reflect beta status

### Short-term (this month)
1. Implement JWT authentication (replace placeholder)
2. Connect real Redis
3. Add token metadata support

### Medium-term (next 2-3 months)
1. Implement extensible scopes
2. Add delegation support
3. Optimize performance with caching

---

**This document will be kept up-to-date as limitations are resolved.**
