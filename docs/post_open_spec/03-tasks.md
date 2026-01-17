# Implementation Tasks
## Thalamus: Identity Server for the Agentic Economy

**Document Version:** 1.0
**Date:** January 16, 2026
**Status:** Ready for Implementation
**Prerequisites:**
- [Requirements Document](01-requirements.md) - APPROVED
- [Design Documents](02-design-index.md) - APPROVED

---

## Implementation Strategy

### Guiding Principles

1. **Incremental Delivery** - Each epic delivers working, testable functionality
2. **Test-First Approach** - Write tests before implementation (TDD where applicable)
3. **Backward Compatibility** - All changes are additive, zero breaking changes
4. **Feature Flag Isolation** - New features behind `ENABLE_AGENT_TOKENS` flag
5. **Clean Architecture** - Strict layer separation, SOLID principles enforced

### Epic Organization

The implementation is organized into 8 epics, executed in order:

1. **Foundation** - Domain layer (entities, value objects)
2. **Persistence** - Database migrations, repositories
3. **Core Logic** - Application layer (use cases, ports)
4. **API Layer** - Controllers, error handling
5. **Performance** - ETS caching, optimization
6. **Security** - Multi-tenant isolation, rate limiting
7. **Observability** - Metrics, logging, monitoring
8. **Migration & Rollout** - Feature flags, deployment

---

## Epic 1: Foundation (Domain Layer)

**Goal:** Implement pure business logic with zero external dependencies

### 1.1 Agent Value Objects

- [ ] Create `AgentType` value object
  - [ ] Validate types: `autonomous`, `supervisor`, `tool`
  - [ ] Implement `String.Chars` protocol
  - [ ] Implement `Jason.Encoder` protocol
  - [ ] Write unit tests (100% coverage)
  - [ ] Location: `lib/thalamus/domain/value_objects/agent_type.ex`

- [ ] Create `TaskId` value object
  - [ ] UUID validation using `Ecto.UUID.cast/1`
  - [ ] Implement protocols (String.Chars, Jason.Encoder)
  - [ ] Write unit tests (100% coverage)
  - [ ] Location: `lib/thalamus/domain/value_objects/task_id.ex`

- [ ] Create `DelegationChain` value object
  - [ ] Struct: `parent_token_id`, `depth`, `path`
  - [ ] Validate `depth < 5` (MAX_DEPTH constant)
  - [ ] Implement `exceeds_max_depth?/1` function
  - [ ] Implement protocols
  - [ ] Write unit tests including edge cases (max depth, nil parent)
  - [ ] Location: `lib/thalamus/domain/value_objects/delegation_chain.ex`

### 1.2 AgentToken Entity

- [ ] Create `AgentToken` entity
  - [ ] Define struct with all fields (id, access_token, agent_type, task_id, delegation_chain, scopes, reason, expires_at, revoked_at, organization_id, client_id)
  - [ ] Implement `create/1` - validates attrs and returns `{:ok, token}` or `{:error, reason}`
  - [ ] Implement `revoke/1` - sets `revoked_at` timestamp
  - [ ] Implement `active?/1` - checks not revoked and not expired
  - [ ] Implement `expired?/1` - compares `expires_at` with current time
  - [ ] Write comprehensive unit tests (100% coverage)
  - [ ] Location: `lib/thalamus/domain/entities/agent_token.ex`

**Acceptance Criteria:**
- All domain tests pass (`mix test test/thalamus/domain/`)
- Zero dependencies on Ecto, Phoenix, or external libraries
- 100% test coverage on domain layer
- All value objects implement required protocols

---

## Epic 2: Persistence (Infrastructure Layer)

**Goal:** Database schema and repository implementations

### 2.1 Database Migration

- [ ] Create migration: `20260117_add_agent_tokens_table.exs`
  - [ ] Create `agent_tokens` table with all fields
  - [ ] Add foreign keys: `client_id`, `organization_id`, `parent_agent_id`
  - [ ] Add check constraint: `agent_type IN ('autonomous', 'supervisor', 'tool')`
  - [ ] Add check constraint: `delegation_depth >= 0 AND delegation_depth < 5`
  - [ ] Create index: `idx_agent_tokens_access_token` (partial, WHERE revoked_at IS NULL)
  - [ ] Create index: `idx_agent_tokens_organization_id`
  - [ ] Create index: `idx_agent_tokens_parent_agent_id` (partial, WHERE parent_agent_id IS NOT NULL)
  - [ ] Create index: `idx_agent_tokens_task_id`
  - [ ] Create index: `idx_agent_tokens_expires_at` (partial, WHERE revoked_at IS NULL)
  - [ ] Create GIN index: `idx_agent_tokens_delegation_chain` on JSONB field
  - [ ] Create partial composite index: `idx_agent_tokens_active` on (client_id, organization_id) WHERE revoked_at IS NULL AND expires_at > NOW()
  - [ ] Test migration: `mix ecto.migrate` (dev and test)
  - [ ] Test rollback: `mix ecto.rollback`
  - [ ] Verify existing tables unchanged (backward compatibility)
  - [ ] Location: `priv/repo/migrations/20260117_add_agent_tokens_table.exs`

### 2.2 Ecto Schema

- [ ] Create `AgentTokenSchema`
  - [ ] Define schema with all fields matching migration
  - [ ] Define associations: `belongs_to :client`, `belongs_to :organization`, `belongs_to :parent_agent, AgentTokenSchema`
  - [ ] Define `has_many :child_agents, AgentTokenSchema, foreign_key: :parent_agent_id`
  - [ ] Implement `changeset/2` for inserts
  - [ ] Implement `update_changeset/2` for updates (revocation)
  - [ ] Write changeset tests (valid/invalid data)
  - [ ] Location: `lib/thalamus/infrastructure/persistence/schemas/agent_token_schema.ex`

### 2.3 Repository Implementation

- [ ] Create `AgentTokenRepository` port (behaviour)
  - [ ] Define callbacks: `save/1`, `find_by_id/1`, `find_by_access_token/1`, `revoke/1`, `revoke_delegation_chain/1`, `find_by_organization/2`
  - [ ] Add typespecs for all callbacks
  - [ ] Location: `lib/thalamus/application/ports/agent_token_repository.ex`

- [ ] Create `PostgresqlAgentTokenRepository`
  - [ ] Implement `@behaviour AgentTokenRepository`
  - [ ] Implement `save/1` - converts domain entity to changeset, inserts/updates, converts back to domain
  - [ ] Implement `find_by_id/1` - queries by UUID, converts to domain entity
  - [ ] Implement `find_by_access_token/1` - queries by token string
  - [ ] Implement `revoke/1` - sets `revoked_at = NOW()`
  - [ ] Implement `revoke_delegation_chain/1` - SQL query using JSONB operators to find children
  - [ ] Implement `find_by_organization/2` - filters by organization_id with pagination
  - [ ] Implement `to_domain/1` - maps Ecto schema to domain entity
  - [ ] Implement `to_changeset/1` - maps domain entity to Ecto changeset
  - [ ] Write integration tests using `DataCase` (async: true with sandbox)
  - [ ] Test all CRUD operations
  - [ ] Test delegation chain revocation (create parent + 3 children, revoke parent, verify all revoked)
  - [ ] Location: `lib/thalamus/infrastructure/repositories/postgresql_agent_token_repository.ex`

**Acceptance Criteria:**
- Migration runs cleanly in dev and test
- All repository tests pass with database
- Delegation chain revocation works correctly
- Multi-tenant isolation enforced at query level

---

## Epic 3: Core Logic (Application Layer)

**Goal:** Business workflows and use cases

### 3.1 DTOs

- [ ] Create `AgentTokenRequest` DTO
  - [ ] Fields: `client_id`, `client_secret`, `agent_type`, `task_id`, `scopes`, `reason`, `parent_agent_id`, `organization_id`
  - [ ] Validation: required fields, valid agent_type, valid task_id UUID
  - [ ] Location: `lib/thalamus/application/dtos/agent_token_request.ex`

- [ ] Create `AgentTokenResponse` DTO
  - [ ] Fields: `access_token`, `token_type`, `expires_in`, `agent_metadata` (agent_type, task_id, delegation_chain)
  - [ ] Implement `to_json/1` for HTTP response
  - [ ] Location: `lib/thalamus/application/dtos/agent_token_response.ex`

### 3.2 Delegation Chain Validator Service

- [ ] Create `DelegationChainValidator`
  - [ ] Implement `validate/1` - given parent_agent_id, validates:
    - [ ] Parent token exists
    - [ ] Parent token is active (not revoked, not expired)
    - [ ] Parent token has delegation permission in scopes
    - [ ] Delegation depth < 5
  - [ ] Returns `{:ok, delegation_chain}` or `{:error, reason}`
  - [ ] Write unit tests with mocked repository
  - [ ] Location: `lib/thalamus/application/services/delegation_chain_validator.ex`

### 3.3 GenerateAgentToken Use Case

- [ ] Create `GenerateAgentToken` use case
  - [ ] Define `deps` typespec (agent_token_repository, oauth2_client_repository, delegation_validator, cache_service, audit_logger)
  - [ ] Implement `execute/2` with `with` pipeline:
    - [ ] Fetch OAuth2 client by client_id
    - [ ] Validate client_secret (constant-time compare)
    - [ ] Validate requested scopes against client.allowed_scopes
    - [ ] Validate delegation chain (if parent_agent_id present)
    - [ ] Generate access_token (`:crypto.strong_rand_bytes(32) |> Base.url_encode64`)
    - [ ] Create AgentToken entity
    - [ ] Save to repository
    - [ ] Cache token (optional, for introspection performance)
    - [ ] Log audit event (async, non-blocking)
    - [ ] Return AgentTokenResponse
  - [ ] Implement private helper functions: `fetch_client/2`, `validate_client_secret/3`, `validate_scopes/2`, `validate_delegation/2`, `create_agent_token/3`, `save_token/2`, `cache_token/2`, `log_token_issuance/3`, `to_response/1`
  - [ ] Write unit tests using Mox to mock all dependencies
  - [ ] Test happy path (successful token generation)
  - [ ] Test error cases: invalid client, invalid secret, invalid scopes, max delegation depth, revoked parent
  - [ ] Achieve 90%+ test coverage
  - [ ] Location: `lib/thalamus/application/use_cases/generate_agent_token.ex`

### 3.4 RevokeAgentToken Use Case

- [ ] Create `RevokeAgentToken` use case
  - [ ] Implement `execute/2` - takes token_id, revokes it
  - [ ] If token has children (delegation), revoke entire chain
  - [ ] Invalidate cache for all revoked tokens
  - [ ] Broadcast cache invalidation via Phoenix.PubSub
  - [ ] Log audit event
  - [ ] Write tests for single revocation and cascade revocation
  - [ ] Location: `lib/thalamus/application/use_cases/revoke_agent_token.ex`

**Acceptance Criteria:**
- All use case tests pass with 90%+ coverage
- Error handling covers all edge cases
- Mox used to mock all external dependencies

---

## Epic 4: API Layer (Presentation Layer)

**Goal:** HTTP endpoints and error handling

### 4.1 Agent Token Controller

- [ ] Create `AgentTokenController`
  - [ ] Define `@deps` map with production implementations
  - [ ] Implement `create/2` action:
    - [ ] Parse params into `AgentTokenRequest`
    - [ ] Extract organization_id from authenticated session or client credentials
    - [ ] Call `GenerateAgentToken.execute(request, @deps)`
    - [ ] Return 200 OK with JSON response on success
    - [ ] Return appropriate error responses (400, 401, 403, 429, 500)
  - [ ] Implement `build_request/1` - parses conn params into DTO
  - [ ] Implement error handling with Stripe-level error messages:
    - [ ] `:invalid_client` → 401 with error code and docs URL
    - [ ] `:invalid_scope` → 403 with details of which scopes are invalid
    - [ ] `:max_delegation_depth_exceeded` → 400 with delegation path
    - [ ] `:parent_token_revoked` → 400 with parent info
    - [ ] Generic errors → 500 with request_id for support
  - [ ] Write controller tests using `ConnCase`
  - [ ] Test successful token generation (POST /oauth/agent-token)
  - [ ] Test all error cases
  - [ ] Test authentication (client credentials in Authorization header)
  - [ ] Location: `lib/thalamus_web/controllers/oauth2/agent_token_controller.ex`

### 4.2 Router Integration

- [ ] Add agent token route to router
  - [ ] Add `post "/oauth/agent-token", AgentTokenController, :create` to `:oauth2_api` pipeline
  - [ ] Ensure route uses existing authentication plugs
  - [ ] Ensure rate limiting applies (1000 req/min per client)
  - [ ] Test route is accessible at correct path
  - [ ] Location: `lib/thalamus_web/router.ex`

### 4.3 Error View/JSON Serialization

- [ ] Create standardized error JSON format
  - [ ] Template: `%{error: %{code: string, message: string, documentation_url: string, request_id: string, timestamp: string, details: map}}`
  - [ ] Implement `render_error/3` helper
  - [ ] Add documentation URLs for all error codes
  - [ ] Location: `lib/thalamus_web/controllers/error_helpers.ex` or similar

**Acceptance Criteria:**
- Controller tests pass with ConnCase
- Error responses follow Stripe-level format
- Route accessible and properly authenticated
- Rate limiting enforced

---

## Epic 5: Performance (Caching & Optimization)

**Goal:** Sub-5ms p99 latency via ETS caching

### 5.1 ETS Cache Adapter

- [ ] Create `ETSCacheAdapter`
  - [ ] Implement GenServer with `:ets.new/2` in `init/1`
  - [ ] Configure ETS table: `:named_table`, `:set`, `:public`, `read_concurrency: true`, `write_concurrency: true`
  - [ ] Implement `get/1` - looks up key, checks expiration, returns `{:ok, value}` or `{:error, :not_found}`
  - [ ] Implement `put/3` - stores key-value with TTL (default 5 minutes)
  - [ ] Implement `invalidate/1` - deletes key from ETS + broadcasts to other nodes via PubSub
  - [ ] Implement PubSub listener - subscribes to "cache:invalidation" topic
  - [ ] Handle `{:invalidate, key}` messages - delete from local ETS
  - [ ] Write unit tests for cache operations
  - [ ] Write integration tests for multi-node invalidation (use 2 nodes)
  - [ ] Location: `lib/thalamus/infrastructure/adapters/ets_cache_adapter.ex`

### 5.2 CachedValidateToken Use Case

- [ ] Create `CachedValidateToken` use case (wrapper for introspection)
  - [ ] Check ETS cache first
  - [ ] On cache miss, query database via repository
  - [ ] Store result in cache (only if active)
  - [ ] Return token metadata
  - [ ] Write tests measuring cache hit/miss performance
  - [ ] Location: `lib/thalamus/application/use_cases/cached_validate_token.ex`

### 5.3 Token Introspection Endpoint (Enhancement)

- [ ] Update `IntrospectionController` to use ETS cache
  - [ ] Replace direct database queries with `CachedValidateToken`
  - [ ] Measure latency improvement (should go from ~10ms to ~0.5ms on cache hit)
  - [ ] Write performance tests
  - [ ] Location: `lib/thalamus_web/controllers/oauth2/introspection_controller.ex`

### 5.4 Performance Benchmarking

- [ ] Create benchmark suite
  - [ ] Benchmark M2M token generation (target: p99 < 5ms)
  - [ ] Benchmark token introspection with cache (target: p99 < 3ms)
  - [ ] Benchmark delegation chain revocation (target: < 10ms for depth 5)
  - [ ] Run with `mix test --only benchmark`
  - [ ] Location: `test/thalamus/performance/token_generation_benchmark_test.exs`

**Acceptance Criteria:**
- ETS cache operational with PubSub invalidation
- Cache hit rate >95% after warm-up
- Token introspection p99 < 3ms with cache
- M2M token generation p99 < 5ms

---

## Epic 6: Security (Multi-Tenant & Rate Limiting)

**Goal:** Ensure organization isolation and prevent abuse

### 6.1 Multi-Tenant Isolation

- [ ] Add organization_id filtering to all agent token queries
  - [ ] Update `find_by_organization/2` to enforce organization_id
  - [ ] Update `find_by_access_token/1` to check organization_id matches session
  - [ ] Add tests: User A cannot access User B's agent tokens (different orgs)
  - [ ] Location: Repository layer

- [ ] Add organization context plug
  - [ ] Extract organization_id from authenticated session/client
  - [ ] Store in conn assigns for use in controllers
  - [ ] Reject requests with no valid organization
  - [ ] Location: `lib/thalamus_web/plugs/set_organization_context.ex`

### 6.2 Rate Limiting

- [ ] Configure rate limits for agent token endpoint
  - [ ] 1,000 requests/minute per client_id
  - [ ] Return 429 with `Retry-After` header
  - [ ] Return error JSON with quota information
  - [ ] Write tests to verify rate limiting works
  - [ ] Location: Router pipeline or controller

### 6.3 Security Audit

- [ ] Constant-time token comparison
  - [ ] Verify all token validations use `Plug.Crypto.secure_compare/2`
  - [ ] Audit code for timing attack vulnerabilities

- [ ] Input sanitization
  - [ ] Sanitize `reason` field (natural language) to prevent XSS
  - [ ] Validate all UUIDs using `Ecto.UUID.cast/1`
  - [ ] Validate agent_type against whitelist

- [ ] SQL injection prevention
  - [ ] Verify all queries use Ecto parameterization
  - [ ] No raw SQL with string interpolation

**Acceptance Criteria:**
- Multi-tenant tests pass (organization isolation verified)
- Rate limiting enforced and tested
- Security audit checklist completed

---

## Epic 7: Observability (Metrics & Logging)

**Goal:** Production-ready monitoring and debugging

### 7.1 Telemetry Events

- [ ] Add telemetry events to `GenerateAgentToken`
  - [ ] Emit `[:thalamus, :agent_token, :generate, :start]`
  - [ ] Emit `[:thalamus, :agent_token, :generate, :stop]` with duration
  - [ ] Emit `[:thalamus, :agent_token, :generate, :exception]` on errors
  - [ ] Include metadata: agent_type, task_id, organization_id, delegation_depth
  - [ ] Location: In use case execution

- [ ] Add telemetry events to cache operations
  - [ ] Emit `[:thalamus, :cache, :hit]` and `[:thalamus, :cache, :miss]`
  - [ ] Track cache hit rate
  - [ ] Location: In ETSCacheAdapter

### 7.2 Prometheus Metrics

- [ ] Configure Prometheus metrics exporter
  - [ ] Histogram: `thalamus_agent_token_generation_duration_milliseconds`
  - [ ] Histogram: `thalamus_token_introspection_duration_milliseconds`
  - [ ] Counter: `thalamus_agent_tokens_issued_total` (labels: agent_type, organization_id)
  - [ ] Gauge: `thalamus_cache_hit_rate`
  - [ ] Histogram: `thalamus_delegation_chain_depth`
  - [ ] Attach handlers to telemetry events
  - [ ] Test metrics endpoint `/metrics`
  - [ ] Location: `lib/thalamus/telemetry.ex`

### 7.3 Audit Logging

- [ ] Enhance audit logger for agent tokens
  - [ ] Log `agent_token_issued` event with metadata (agent_type, task_id, scopes, reason)
  - [ ] Log `agent_token_revoked` event
  - [ ] Log `delegation_chain_revoked` event with count of revoked children
  - [ ] Async logging (non-blocking)
  - [ ] Test audit log entries created
  - [ ] Location: `lib/thalamus/infrastructure/adapters/audit_logger_impl.ex`

**Acceptance Criteria:**
- Telemetry events emitted correctly
- Prometheus metrics exposed at `/metrics`
- Audit logs capture all security events
- Performance impact minimal (<1ms overhead)

---

## Epic 8: Migration & Rollout

**Goal:** Zero-downtime deployment with gradual rollout

### 8.1 Feature Flag Implementation

- [ ] Add `ENABLE_AGENT_TOKENS` environment variable
  - [ ] Default: `false` (disabled)
  - [ ] Read from `System.get_env/2`
  - [ ] Location: `config/runtime.exs`

- [ ] Create `FeatureFlags` module
  - [ ] Implement `agent_tokens_enabled?/1` - checks global flag + per-org setting
  - [ ] Add per-organization flag in `organizations.settings` JSONB
  - [ ] Write tests for flag logic
  - [ ] Location: `lib/thalamus/feature_flags.ex`

- [ ] Integrate flag in `AgentTokenController`
  - [ ] Check flag before executing use case
  - [ ] Return 404 if feature disabled
  - [ ] Test both enabled and disabled states
  - [ ] Location: Controller create action

### 8.2 Backward Compatibility Testing

- [ ] Verify existing OAuth2 flows unchanged
  - [ ] Test Authorization Code + PKCE flow
  - [ ] Test Client Credentials flow
  - [ ] Test Refresh Token flow
  - [ ] Test Token Introspection
  - [ ] Test Token Revocation
  - [ ] All existing tests must pass without modification

- [ ] Database compatibility
  - [ ] Verify migration is additive-only
  - [ ] Verify rollback works cleanly
  - [ ] Verify no changes to existing tables

### 8.3 Deployment Documentation

- [ ] Create deployment checklist
  - [ ] Phase 1: Deploy with `ENABLE_AGENT_TOKENS=false`, run migrations
  - [ ] Phase 2: Enable for test organization, monitor 24h
  - [ ] Phase 3: Gradual rollout (10% → 50% → 100%)
  - [ ] Phase 4: Remove feature flag
  - [ ] Location: `docs/post_open_spec/04-deployment-checklist.md`

- [ ] Rollback plan
  - [ ] Document emergency disable: `kubectl set env deployment/thalamus ENABLE_AGENT_TOKENS=false`
  - [ ] Document per-org disable SQL
  - [ ] Document full rollback to previous version

**Acceptance Criteria:**
- Feature flag works correctly (global + per-org)
- All existing tests pass (zero breaking changes)
- Deployment documentation complete
- Rollback plan tested

---

## Testing Summary

### Coverage Targets

- **Domain Layer**: 100% (pure unit tests, no mocks)
- **Application Layer**: 90% (use case tests with Mox)
- **Infrastructure Layer**: 80% (integration tests with DB)
- **Web Layer**: 85% (controller tests with ConnCase)

### Test Execution

```bash
# Run all tests
mix test

# Run domain tests only (fast)
mix test test/thalamus/domain/

# Run with coverage
mix test --cover

# Run performance benchmarks
mix test --only benchmark

# Run integration tests
mix test test/thalamus/infrastructure/
```

### CI/CD Requirements

- [ ] All tests pass on every commit
- [ ] Code coverage ≥80% (fail build if below)
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes (no warnings)
- [ ] Dialyzer checks pass (optional, can be slow)

---

## Next Steps After Implementation

1. **Phase 3 Implementation** - Execute tasks above (estimated 3-4 weeks for team of 2-3)
2. **Load Testing** - Run K6 tests to verify 10k RPS capability
3. **Security Audit** - External review of authentication flow
4. **Documentation** - Complete SDK docs, API reference, integration guides
5. **Early Adopter Rollout** - Deploy to 5-10 pilot customers
6. **Monitoring Setup** - Configure Grafana dashboards, alerts
7. **SDK Development** - Build Python SDK first, then TypeScript

---

**Document End**

**Ready to begin implementation!**
