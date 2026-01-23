# Requirements Document
## Thalamus: Generic OAuth2 Server with Multi-Agent Extensions

**Document Version:** 1.1
**Date:** January 20, 2026
**Status:** Implemented (73% Complete)
**Target:** Developer Experience at Stripe Level for AI Agent Authentication

**Scope:** Generic OAuth2/OIDC server with agent token extensions for ANY multi-agent system (not application-specific)

---

## 1. Introduction

### 1.1 Purpose and Scope

This document defines the functional and non-functional requirements for **Thalamus**, a high-performance Identity Provider (IdP) with **generic multi-agent extensions**. Thalamus provides standard OAuth2/OIDC authentication plus agent token features that work with ANY multi-agent system (LangChain, AutoGPT, CrewAI, LangGraph, custom frameworks). It addresses the structural obsolescence of incumbent authentication providers (Auth0/Okta, Clerk, Keycloak, Stytch) when applied to high-frequency Machine-to-Machine (M2M) authentication for autonomous AI agents.

### 1.2 Problem Statement

Current identity providers face three critical failures in the emerging Agentic Economy:

1. **Economic Collapse ("The IdP Tax"):** Traditional pricing models based on Monthly Active Users (MAU) are predatory when applied to M2M authentication. A fleet of 1,000 agents generating 10 million tokens/month incurs costs of $10,000-$50,000 USD/month with existing providers, versus ~$333 USD/month with Thalamus architecture (99%+ cost reduction).

2. **Technical Friction ("The Java/Node Wall"):** Legacy infrastructure based on JVM (Keycloak) and Node.js Event Loop (Auth0) cannot guarantee deterministic latency required by Agent Swarms. Garbage Collection "Stop-the-World" events introduce tail latency spikes (p99 > 500ms) that break Chain-of-Thought reasoning in LLMs and increase inference costs.

3. **Security Gap in Emerging Protocols:** The explosive adoption of Anthropic's Model Context Protocol (MCP) has created critical attack vectors (Confused Deputy problem, token theft in local servers). The market lacks an identity orchestrator implementing native support for emerging security specifications like the IETF "AAuth" (Agentic Authorization) draft.

### 1.3 Solution Overview

Thalamus leverages the **Elixir/BEAM technical moat** to deliver:
- **<5ms p99 latency** through per-process garbage collection and preemptive scheduling
- **99% cost reduction** through self-hosted efficiency on AWS Graviton (ARM64)
- **Developer Experience at Stripe level** with ergonomic SDKs, clear documentation, and real-time observability
- **Native support for Agentic protocols:** MCP Gateway, AAuth implementation, delegation chains

### 1.4 Target Market Segment

**Primary:** Companies building autonomous AI agent fleets (1,000+ agents) requiring:
- High-frequency ephemeral token generation (10M+ tokens/month)
- Sub-5ms authentication latency for real-time agent coordination
- Least-privilege security model with dynamic scope assignment
- Cost-effective infrastructure at scale

**Secondary:** Existing SaaS requiring human authentication with multi-tenant isolation.

---

## 2. User Stories and Actors

### 2.1 Primary Actors

1. **AI Agent (Autonomous):** Non-human actor powered by LLM, dynamically decides which tools to invoke, databases to query, and agents to collaborate with
2. **Platform Developer:** Engineer building AI agent infrastructure, requires low-latency M2M authentication
3. **Security Engineer:** Responsible for implementing least-privilege access, monitoring non-human identities, preventing prompt injection risks
4. **DevOps Engineer:** Manages infrastructure deployment, monitoring, and cost optimization
5. **End User (Human):** Uses applications powered by AI agents (indirect beneficiary of Thalamus performance)

### 2.2 User Stories

#### US-001: High-Frequency Token Generation for Agent Fleet
**As a** Platform Developer
**I want** my AI agents to request ephemeral M2M tokens with minimal latency
**So that** agent coordination is not bottlenecked by authentication overhead and I can maintain <100ms total response time to end users

#### US-002: Cost-Effective Authentication at Scale
**As a** Platform Developer
**I want** authentication costs that scale linearly with my business (not token count)
**So that** I can operate a fleet of 1,000+ agents without incurring $10k-$50k/month in IdP taxes

#### US-003: Least-Privilege Dynamic Scopes for Agents
**As a** Security Engineer
**I want** agents to request tokens with granular, task-specific scopes every 5 minutes
**So that** I minimize blast radius from prompt injection attacks and comply with zero-trust security policies

#### US-004: MCP Integration with Confused Deputy Protection
**As a** Platform Developer
**I want** a secure gateway for MCP servers (Gmail, Slack, GitHub)
**So that** my agents can access external tools without exposing static API keys or falling victim to deputy confusion attacks

#### US-005: Stripe-Level Developer Experience
**As a** Platform Developer
**I want** SDK libraries in Python, TypeScript, Go with clear documentation and code examples
**So that** I can integrate Thalamus in <30 minutes without learning Elixir internals

#### US-006: Real-Time Observability and Audit Logs
**As a** Security Engineer
**I want** real-time dashboards showing agent authentication patterns, anomalies, and delegation chains
**So that** I can detect compromised agents or credential leaks immediately

#### US-007: AAuth Standard Compliance
**As a** Security Engineer
**I want** native support for IETF AAuth (Agentic Authorization) protocol
**So that** I future-proof my infrastructure against evolving AI security standards and demonstrate compliance to auditors

#### US-008: Multi-Tenant Isolation for Agent Fleets
**As a** Platform Developer
**I want** strict organizational boundaries that isolate agent fleets by company
**So that** agents from Organization A never access tokens, clients, or data from Organization B

---

## 3. Functional Requirements

### 3.1 Core Authentication Engine

#### REQ-AUTH-001: OAuth2 Client Credentials Flow (M2M)
**Priority:** CRITICAL
**Acceptance Criteria:**

1. WHEN an agent requests a token using client_credentials grant THEN Thalamus SHALL issue an access token in <5ms (p99)
2. IF the client_id and client_secret are valid THEN the system SHALL generate a JWT with configurable TTL (default: 300 seconds)
3. IF the client credentials are invalid THEN the system SHALL return HTTP 401 with error code "invalid_client" in <2ms
4. WHERE load exceeds 10,000 requests/second THEN the system SHALL maintain p99 latency <5ms through ETS caching and BEAM process isolation
5. WHILE generating tokens THEN the system SHALL use cryptographically secure randomness (:crypto.strong_rand_bytes/1)

#### REQ-AUTH-002: Token Introspection (RFC 7662)
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN an agent or resource server validates a token via /oauth/introspect THEN the system SHALL return active/inactive status in <3ms (p99)
2. IF the token is stored in ETS cache THEN lookup SHALL complete in <1ms
3. IF the token is expired or revoked THEN the response SHALL indicate "active: false" with appropriate metadata
4. WHERE introspection rate exceeds 50,000 RPS THEN the system SHALL scale horizontally without Redis dependency

#### REQ-AUTH-003: Token Revocation (RFC 7009)
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN a security engineer revokes a token via /oauth/revoke THEN the system SHALL invalidate it in ETS cache within 100ms
2. WHEN a token is revoked THEN all subsequent introspection requests SHALL return "active: false"
3. IF an agent attempts to use a revoked token THEN resource servers SHALL reject it with HTTP 401

#### REQ-AUTH-004: Refresh Token Rotation
**Priority:** MEDIUM
**Acceptance Criteria:**

1. WHEN an agent uses a refresh token to obtain a new access token THEN the system SHALL issue a new refresh token and invalidate the old one (rotation)
2. IF a revoked refresh token is reused THEN the system SHALL revoke the entire token family and trigger a security alert
3. WHERE refresh token TTL is configurable THEN the default SHALL be 30 days with automatic expiration

### 3.2 Agent-Specific Features

#### REQ-AGENT-001: Agent Token Generation Endpoint ✅ IMPLEMENTED
**Priority:** CRITICAL
**Status:** Production-Ready (100% test coverage - 53/53 tests passing)
**Acceptance Criteria:**

1. WHEN an agent requests a token via POST /oauth/agent-token THEN the system SHALL accept parameters: agent_type, task_id, delegated_by_user_id, task_scopes, intent_description ✅
2. IF delegation_chain validation is enabled THEN the system SHALL verify parent delegation chain depth < 10 ✅
3. WHEN issuing an agent token THEN the system SHALL embed metadata: agent_type (autonomous, supervisor, tool), task_id, delegation_chain ✅
4. WHERE the agent provides a natural language "intent_description" THEN the system SHALL log it for human auditing without blocking token issuance ✅

**Generic Use Cases:**
- LangChain: Autonomous agents requesting scoped tokens for tool execution
- AutoGPT: Supervisor agents delegating to specialist agents
- CrewAI: Task-specific tokens for crew member agents
- LangGraph: Orchestrator nodes creating tokens for subgraph execution

#### REQ-AGENT-002: Delegation Chain Validation ✅ IMPLEMENTED
**Priority:** HIGH
**Status:** Production-Ready (100% test coverage - 34/34 tests passing)
**Acceptance Criteria:**

1. WHEN an agent token is created THEN the system SHALL track the delegation chain from original user to agent ✅
2. IF the delegation depth exceeds 10 levels THEN the system SHALL reject the request with error "delegation_chain_too_deep" ✅
3. WHERE delegation chains are used THEN the system SHALL support recursive validation (user → supervisor → specialist) ✅

**Generic Pattern:** Universal for ANY agent orchestration (human → coordinator agent → specialist agent → tool agent)

#### REQ-AGENT-003: Granular Scope Management ✅ IMPLEMENTED
**Priority:** HIGH
**Status:** Production-Ready (fully configurable scopes)
**Acceptance Criteria:**

1. WHEN an agent requests specific scopes (e.g., "api:read", "db:write", "service:execute") THEN the system SHALL validate them against the client's allowed_scopes ✅
2. IF requested scopes exceed allowed_scopes THEN the system SHALL return HTTP 403 with error "insufficient_scope" ✅
3. WHERE scopes are used THEN the system SHALL support ANY custom namespace (e.g., "myapp:resource:action") via runtime configuration ✅
4. WHILE processing scope requests THEN the system SHALL validate against configured scope list (defaults provided, fully customizable) ✅

**Generic Examples:**
- LangChain: `langchain:tool:search`, `langchain:memory:write`
- AutoGPT: `autogpt:goal:execute`, `autogpt:resource:read`
- Custom: `myapp:database:query`, `myapp:api:external:call`

### 3.3 MCP (Model Context Protocol) Integration

#### REQ-MCP-001: MCP Gateway for Confused Deputy Protection
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN an agent connects to an MCP server through Thalamus Gateway THEN the system SHALL intercept the connection and enforce OAuth2 authorization
2. IF the MCP server requires access to Gmail THEN the Thalamus Gateway SHALL request a scoped token from the user via OAuth2 Authorization Code + PKCE flow
3. WHERE multiple agents share an MCP server THEN each SHALL have isolated token storage, preventing cross-contamination
4. WHILE an agent makes an MCP tool invocation THEN the gateway SHALL validate the token scope matches the requested tool before forwarding the request

#### REQ-MCP-002: Dynamic Client Registration for MCP Servers
**Priority:** MEDIUM
**Acceptance Criteria:**

1. WHEN an MCP server is deployed THEN Thalamus SHALL support RFC 7591 Dynamic Client Registration for ephemeral client_id generation
2. IF a client is registered dynamically THEN the system SHALL return client_id and client_secret with a configurable TTL (default: 7 days)
3. WHERE a dynamic client expires THEN the system SHALL automatically revoke all tokens issued to that client

### 3.4 AAuth (Agentic Authorization) Standard Support

#### REQ-AAUTH-001: Natural Language Authorization Requests
**Priority:** MEDIUM
**Acceptance Criteria:**

1. WHEN an agent requests authorization via the AAuth flow THEN the system SHALL accept a human-readable "reason" parameter describing why access is needed
2. IF a human supervisor must approve THEN the system SHALL support asynchronous approval via WebSocket, SSE, or HTTP long-polling
3. WHERE the approval request is pending THEN the agent SHALL receive a "authorization_pending" response with a 5-second retry interval
4. WHILE waiting for approval THEN the system SHALL timeout after 5 minutes and reject with "authorization_timeout"

#### REQ-AAUTH-002: Supervisor Approval UI
**Priority:** LOW
**Acceptance Criteria:**

1. WHEN a human supervisor receives an AAuth approval request THEN they SHALL see: agent_id, task_id, requested scopes, natural language reason, risk assessment
2. IF the supervisor approves THEN the system SHALL issue the token and notify the agent via the configured channel (WebSocket/SSE/polling)
3. IF the supervisor denies THEN the agent SHALL receive "access_denied" with the rejection reason

### 3.5 Multi-Tenant Isolation

#### REQ-TENANT-001: Organization-Based Resource Isolation
**Priority:** CRITICAL
**Acceptance Criteria:**

1. WHEN a user registers THEN the system SHALL automatically create a personal organization with the user as owner
2. WHERE a user creates an OAuth2 client THEN it SHALL be scoped to their organization_id
3. WHEN a user views the dashboard THEN they SHALL only see users, clients, tokens, and agents belonging to their organization
4. IF an API request attempts to access resources from another organization THEN the system SHALL return HTTP 403 "forbidden"

#### REQ-TENANT-002: Cross-Organization Agent Collaboration (Future)
**Priority:** LOW
**Acceptance Criteria:**

1. WHERE Organization A wants to delegate access to Organization B's agent THEN the system SHALL support inter-org delegation tokens with explicit consent
2. WHEN an inter-org token is issued THEN both organizations SHALL receive audit log entries
3. IF either organization revokes the delegation THEN the token SHALL be invalidated immediately

### 3.6 Backward Compatibility and Existing Features

#### REQ-COMPAT-001: Preservation of Existing Functionality
**Priority:** CRITICAL
**Acceptance Criteria:**

1. WHEN implementing new agentic features THEN all existing OAuth2 flows SHALL continue to function without breaking changes: Authorization Code + PKCE, Client Credentials, Refresh Token
2. WHERE Thalamus currently supports human authentication THEN it SHALL maintain full compatibility with existing SaaS applications using session-based login, MFA (TOTP), password reset flows
3. IF the dashboard currently displays users, organizations, OAuth2 clients, and tokens THEN these views SHALL remain functional with the same UI/UX behavior
4. WHEN new agent-specific endpoints are added THEN existing REST API endpoints SHALL maintain their current request/response contracts: `/api/users`, `/api/organizations`, `/api/oauth2_clients`, `/api/mfa`
5. WHERE multi-tenant isolation is already implemented THEN the existing organization_id filtering SHALL be preserved and enhanced (not replaced)
6. IF a developer has integrated Thalamus v1.0.0-rc1 THEN their integration SHALL continue to work after upgrading to the agentic version without code changes
7. WHILE adding new database tables/columns for agent tokens THEN existing migrations SHALL remain valid and the database schema SHALL be extended via additive-only migrations (no destructive changes)
8. WHEN new features are released THEN the system SHALL use feature flags (ENABLE_AGENT_TOKENS) to allow gradual rollout without affecting existing users

**Existing Features to Preserve:**
- OAuth2 Authorization Code flow with PKCE (RFC 7636)
- OAuth2 Client Credentials flow (RFC 6749 Section 4.4)
- OAuth2 Refresh Token flow with rotation (RFC 6749 Section 6)
- Token Introspection endpoint (RFC 7662): `POST /oauth/introspect`
- Token Revocation endpoint (RFC 7009): `POST /oauth/revoke`
- OpenID Connect userinfo endpoint: `GET /oauth/userinfo`
- Session-based authentication: `POST /session/login`, `DELETE /session/logout`
- Multi-factor authentication (TOTP): setup, verify, disable endpoints
- User management API: CRUD operations for users
- Organization management API: CRUD operations for organizations
- OAuth2 Client management API: CRUD operations for clients
- Dashboard LiveView: real-time UI for managing resources
- Audit logging infrastructure: security event persistence
- Rate limiting per IP and per user
- CORS and security headers (CSP, HSTS, X-Frame-Options)

### 3.7 Architecture and Code Quality

#### REQ-ARCH-001: Clean Architecture Compliance
**Priority:** CRITICAL
**Acceptance Criteria:**

1. WHEN implementing new features THEN the code SHALL follow Clean Architecture with strict layer separation: Domain → Application → Infrastructure → Presentation
2. WHERE domain entities are created THEN they SHALL reside in `lib/thalamus/domain/entities/` with zero external dependencies (no Ecto, no Phoenix imports)
3. IF new value objects are needed THEN they SHALL be implemented in `lib/thalamus/domain/value_objects/` with immutability, validation on creation, and protocol implementations (String.Chars, Jason.Encoder)
4. WHEN orchestrating business workflows THEN use cases SHALL be created in `lib/thalamus/application/use_cases/` with dependencies injected via `deps` parameter
5. WHERE external services are required THEN port behaviours SHALL be defined in `lib/thalamus/application/ports/` and implementations SHALL reside in `lib/thalamus/infrastructure/adapters/` or `lib/thalamus/infrastructure/repositories/`
6. IF database persistence is needed THEN Ecto schemas SHALL be isolated in `lib/thalamus/infrastructure/persistence/schemas/` with clear separation from domain entities
7. WHILE writing controllers THEN they SHALL only call use cases and transform HTTP requests/responses, with zero business logic in controllers
8. WHEN dependencies flow THEN they SHALL always point inward: Web → Application → Domain (never Domain → Infrastructure or Application → Web)

**Architecture Validation:**
- Domain layer MUST NOT import from: Ecto, Phoenix, Plug, external libraries (except Elixir stdlib)
- Application layer MUST NOT import from: ThalamusWeb, Phoenix.Controller, Ecto.Schema (only Ecto.Repo for type specs)
- Infrastructure layer MAY import from: Ecto, external adapters, but NOT from ThalamusWeb
- Presentation layer (ThalamusWeb) MAY import from: Application (use cases, DTOs), but NOT from Infrastructure or Domain directly

#### REQ-ARCH-002: SOLID Principles Enforcement
**Priority:** HIGH
**Acceptance Criteria:**

1. **Single Responsibility Principle:**
   - WHEN creating a module THEN it SHALL have exactly one reason to change
   - WHERE a value object validates email THEN it SHALL ONLY validate email (not also hash passwords or generate tokens)
   - IF a use case handles token generation THEN it SHALL NOT also handle user authentication or email sending

2. **Open/Closed Principle:**
   - WHEN extending behavior THEN use Elixir protocols for polymorphism (not case statements on types)
   - WHERE new token types are added THEN extend via protocol implementations, not by modifying existing token modules
   - IF new repository implementations are needed THEN implement the existing port behaviour without changing the port

3. **Liskov Substitution Principle:**
   - WHEN implementing a port behaviour THEN all implementations SHALL honor the behaviour contract exactly
   - WHERE a repository port defines `find_by_id/1` returning `{:ok, entity} | {:error, :not_found}` THEN all implementations SHALL use identical return types
   - IF a mock is used in tests THEN it SHALL be interchangeable with production implementations

4. **Interface Segregation Principle:**
   - WHEN defining port behaviours THEN create small, focused interfaces (not "god behaviours")
   - WHERE repository operations are needed THEN define separate behaviours per entity: UserRepository, TokenRepository, OrganizationRepository (not a single RepositoryPort)
   - IF a service has multiple concerns THEN split into focused ports: AuditLogger, EmailService, CacheService (not a single ServicePort)

5. **Dependency Inversion Principle:**
   - WHEN a use case needs persistence THEN it SHALL depend on a port behaviour (abstraction), not a concrete PostgreSQL repository
   - WHERE external services are called THEN the application layer SHALL define the port, and infrastructure SHALL implement it
   - IF a controller needs to generate tokens THEN it SHALL call a use case (abstraction), not a repository or domain service directly

**SOLID Validation:**
- Code reviews SHALL reject PRs that violate SOLID principles
- Each new module SHALL include a `@moduledoc` comment documenting which SOLID principles apply
- Credo linter SHALL enforce: max module length (500 lines), max function length (50 lines), cyclomatic complexity < 10

#### REQ-ARCH-003: Test Coverage and Quality
**Priority:** CRITICAL
**Acceptance Criteria:**

1. **Test Organization:**
   - WHEN writing tests THEN they SHALL follow the same layer structure: `test/thalamus/domain/`, `test/thalamus/application/`, `test/thalamus/infrastructure/`, `test/thalamus_web/`
   - WHERE domain tests exist THEN they SHALL be pure unit tests with no database, no HTTP, no mocks (fast execution < 100ms per test)
   - IF application layer tests are written THEN they SHALL use Mox to mock port behaviours
   - WHILE testing infrastructure THEN integration tests SHALL use Ecto.Adapters.SQL.Sandbox for database isolation
   - WHEN testing controllers THEN they SHALL use ConnCase helpers with database fixtures

2. **Test Coverage Requirements:**
   - The system SHALL maintain minimum 80% code coverage across all layers
   - WHERE domain entities and value objects exist THEN they SHALL have 100% test coverage (business logic is critical)
   - IF use cases are implemented THEN they SHALL have minimum 90% test coverage including edge cases
   - WHEN new features are added THEN the PR SHALL include tests demonstrating the feature works
   - WHERE bug fixes are committed THEN a regression test SHALL be included to prevent recurrence

3. **Test Quality Standards:**
   - WHEN writing tests THEN they SHALL follow AAA pattern: Arrange, Act, Assert
   - WHERE test data is needed THEN use ExMachina factories in `test/support/fixtures.ex` (not hardcoded data)
   - IF external services are called THEN mock them using Mox (not real API calls)
   - WHILE testing async behavior THEN tests SHALL be marked `async: true` when safe (no shared state)
   - WHEN testing error cases THEN include tests for: invalid input, missing data, timeouts, database failures, race conditions

4. **Continuous Integration:**
   - The system SHALL run all tests on every commit via CI/CD pipeline
   - WHERE tests fail THEN the build SHALL be marked as failed and merging SHALL be blocked
   - IF code coverage drops below 80% THEN the PR SHALL be rejected
   - WHEN linter warnings exist THEN the build SHALL fail (`mix credo --strict`)
   - WHILE deploying THEN all tests SHALL pass and code SHALL be formatted (`mix format --check-formatted`)

**Test Execution Requirements:**
- `mix test` SHALL complete in < 30 seconds for fast feedback
- `mix test --cover` SHALL generate HTML coverage reports in `cover/`
- Domain tests SHALL run in < 5 seconds (pure unit tests are fast)
- Integration tests SHALL use database transactions for isolation (no test pollution)

### 3.8 Developer Experience (DX)

#### REQ-DX-001: Multi-Language SDK Support
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN a developer wants to integrate Thalamus THEN the system SHALL provide official SDKs for: Python, TypeScript/JavaScript, Go, Rust, Java, Kotlin
2. IF the developer uses Python THEN the SDK SHALL support: sync/async client, automatic token refresh, retry logic with exponential backoff, type hints
3. WHERE the SDK is published THEN it SHALL be available on official package managers: PyPI (Python), npm (TypeScript), crates.io (Rust), Go modules, Maven Central (Java/Kotlin)

**Example Python SDK Usage:**
```python
from thalamus import ThalamusClient

# Initialize client
client = ThalamusClient(
    auth_url="https://auth.zea.cl",
    client_id=os.getenv("THALAMUS_CLIENT_ID"),
    client_secret=os.getenv("THALAMUS_CLIENT_SECRET")
)

# Request agent token with delegation
token = await client.get_agent_token(
    agent_type="autonomous",
    task_id="task_abc123",
    scopes=["gmail:read", "slack:write"],
    reason="Analyzing customer emails for support ticket routing"
)

# Use token with automatic refresh
response = client.authenticated_request(
    "GET",
    "https://api.example.com/data",
    token=token
)
```

#### REQ-DX-002: Interactive Documentation
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN a developer visits https://docs.thalamus.io THEN they SHALL see: Getting Started (< 5 min), API Reference, SDK Guides, Architecture Deep Dive, Security Best Practices
2. WHERE code examples are shown THEN they SHALL be runnable in multiple languages (Python, TypeScript, cURL) with syntax highlighting
3. IF a developer searches for "agent token" THEN they SHALL find relevant documentation within 3 clicks
4. WHILE viewing API endpoints THEN the documentation SHALL show: request/response examples, error codes, rate limits, latency expectations

#### REQ-DX-003: Real-Time Observability Dashboard
**Priority:** MEDIUM
**Acceptance Criteria:**

1. WHEN a developer logs into the Thalamus dashboard THEN they SHALL see real-time metrics: requests/second, p50/p95/p99 latency, error rate, active agents
2. IF an anomaly is detected (e.g., p99 > 10ms) THEN the dashboard SHALL highlight it with a visual indicator
3. WHERE a developer views agent activity THEN they SHALL see: agent_id, task_id, scopes requested, delegation chain, last active timestamp
4. WHILE viewing audit logs THEN the developer SHALL be able to filter by: date range, agent_type, organization_id, event type (token_issued, token_revoked, etc.)

#### REQ-DX-004: Stripe-Level Error Messages
**Priority:** HIGH
**Acceptance Criteria:**

1. WHEN an API request fails THEN the error response SHALL include: error code, human-readable message, documentation link, request_id for support
2. IF a rate limit is exceeded THEN the response SHALL include: "Retry-After" header, current quota usage, quota reset timestamp
3. WHERE a validation error occurs THEN the response SHALL specify which field failed validation and why

**Example Error Response:**
```json
{
  "error": {
    "code": "invalid_scope",
    "message": "The scope 'gmail:admin' is not allowed for this client. Allowed scopes: ['gmail:read', 'gmail:write']",
    "documentation_url": "https://docs.thalamus.io/errors/invalid_scope",
    "request_id": "req_abc123xyz",
    "timestamp": "2026-01-16T23:45:00Z"
  }
}
```

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### REQ-PERF-001: Token Generation Latency
**Priority:** CRITICAL
**Acceptance Criteria:**

1. The system SHALL generate M2M tokens with p50 latency < 2ms
2. The system SHALL generate M2M tokens with p95 latency < 4ms
3. The system SHALL generate M2M tokens with p99 latency < 5ms
4. WHERE load exceeds 10,000 RPS THEN the system SHALL maintain the above latency SLAs through horizontal scaling

#### REQ-PERF-002: Token Introspection Latency
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL validate tokens via introspection with p99 latency < 3ms using ETS cache
2. WHERE ETS cache hit rate < 95% THEN the system SHALL log a warning and investigate cache eviction policies
3. IF a token is not in ETS cache THEN PostgreSQL lookup SHALL complete in < 10ms

#### REQ-PERF-003: Throughput Under Load
**Priority:** CRITICAL
**Acceptance Criteria:**

1. A single Thalamus node (c7g.2xlarge - 8 vCPU, 16GB RAM) SHALL sustain 10,000 token generation requests/second with p99 < 5ms
2. WHERE load exceeds single-node capacity THEN the system SHALL scale horizontally to N nodes with linear throughput increase (no Redis bottleneck)
3. WHILE under load THEN CPU utilization SHALL remain < 70% to provide headroom for traffic spikes

### 4.2 Scalability Requirements

#### REQ-SCALE-001: Horizontal Scaling Without Redis
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL use ETS (Erlang Term Storage) for in-memory token caching, eliminating Redis dependency
2. WHERE distributed coordination is required THEN the system SHALL use Phoenix PubSub with PostgreSQL adapter or native BEAM distribution
3. IF a node crashes THEN other nodes SHALL continue serving requests without disruption (share-nothing architecture)

#### REQ-SCALE-002: Database Connection Pooling
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL use a dedicated PostgreSQL connection pool for token operations (default: 50 connections)
2. WHERE connection pool is exhausted THEN the system SHALL queue requests with a 500ms timeout before rejecting with HTTP 503
3. WHILE idle THEN the system SHALL maintain a minimum of 10 warm connections to avoid cold start latency

### 4.3 Security Requirements

#### REQ-SEC-001: Cryptographic Token Generation
**Priority:** CRITICAL
**Acceptance Criteria:**

1. The system SHALL generate tokens using :crypto.strong_rand_bytes/1 (cryptographically secure random)
2. The system SHALL sign JWTs using RS256 or ES256 (asymmetric keys) with 2048-bit minimum key length
3. WHERE client secrets are stored THEN they SHALL be hashed using Bcrypt with cost factor 12

#### REQ-SEC-002: Rate Limiting Per Client
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL enforce rate limits per client_id: 1,000 requests/minute for token generation
2. IF a client exceeds the rate limit THEN the system SHALL return HTTP 429 with "Retry-After" header
3. WHERE rate limits are exceeded repeatedly THEN the system SHALL trigger a security alert and optionally suspend the client

#### REQ-SEC-003: Audit Logging for Compliance
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL log all authentication events: token_issued, token_revoked, token_introspected, client_created, scope_violation
2. WHERE audit logs are stored THEN they SHALL be retained for 90 days (configurable)
3. IF a security incident occurs THEN logs SHALL be exportable in JSON format for forensic analysis

#### REQ-SEC-004: OWASP Top 10 Compliance
**Priority:** CRITICAL
**Acceptance Criteria:**

1. The system SHALL prevent SQL Injection through parameterized queries (Ecto)
2. The system SHALL prevent XSS attacks by sanitizing all HTML output (Phoenix.HTML.raw only for trusted content)
3. The system SHALL prevent CSRF attacks using Phoenix's built-in CSRF token validation
4. The system SHALL enforce HTTPS-only connections in production with HSTS headers

### 4.4 Reliability Requirements

#### REQ-REL-001: Fault Tolerance
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL use BEAM supervision trees to automatically restart crashed processes
2. IF a token generation request crashes THEN it SHALL return HTTP 500 and log the error without affecting other requests
3. WHERE database connection fails THEN the system SHALL retry 3 times with exponential backoff before returning HTTP 503

#### REQ-REL-002: Zero-Downtime Deployments
**Priority:** MEDIUM
**Acceptance Criteria:**

1. The system SHALL support hot code upgrades using Elixir releases
2. WHERE a new version is deployed THEN active connections SHALL be drained gracefully (30-second timeout)
3. IF a deployment fails THEN the system SHALL automatically rollback to the previous version

### 4.5 Operational Requirements

#### REQ-OPS-001: Infrastructure Cost Target
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL operate on AWS Graviton (c7g.2xlarge + RDS db.m7g.large) for ~$333 USD/month to support 10M tokens/month
2. WHERE load increases THEN incremental cost SHALL scale linearly (no per-token pricing)
3. IF ETS eliminates Redis THEN the system SHALL save $50-200/month in ElastiCache costs

#### REQ-OPS-002: Observability and Monitoring
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL expose Prometheus metrics: request_count, latency_histogram, error_rate, cache_hit_rate, active_connections
2. WHERE metrics are collected THEN they SHALL be scraped every 15 seconds
3. IF p99 latency exceeds 10ms THEN an alert SHALL be triggered

#### REQ-OPS-003: Self-Hosting Support
**Priority:** HIGH
**Acceptance Criteria:**

1. The system SHALL provide a Docker Compose file for local development
2. The system SHALL provide deployment guides for: AWS (ECS/EKS), DigitalOcean (Droplet), Fly.io, Render
3. WHERE self-hosted THEN the system SHALL include database migration scripts and health check endpoints

---

## 5. Edge Cases and Constraints

### 5.1 Edge Cases

#### EDGE-001: Clock Skew Between Nodes
**Scenario:** Multiple Thalamus nodes have clock skew > 5 seconds
**Requirement:**
- WHEN token expiration is checked THEN the system SHALL use JWT "exp" claim as source of truth
- IF clock skew is detected THEN the system SHALL log a warning but continue operation
- WHERE NTP is unavailable THEN the system SHALL tolerate up to 30 seconds of skew

#### EDGE-002: Agent Request Burst (Thundering Herd)
**Scenario:** 10,000 agents simultaneously request token renewal
**Requirement:**
- WHEN a burst occurs THEN the system SHALL leverage BEAM's lightweight processes to handle 10,000 concurrent requests
- IF ETS cache is warm THEN latency SHALL remain < 5ms p99
- WHERE database connection pool is saturated THEN the system SHALL apply exponential backoff and return HTTP 503 to prevent cascading failure

#### EDGE-003: Prompt Injection Attempt
**Scenario:** Agent sends malicious natural language "reason" in AAuth request
**Requirement:**
- WHEN a reason is provided THEN the system SHALL sanitize it to prevent XSS in admin UI
- IF the reason contains suspicious patterns (e.g., SQL injection, script tags) THEN the system SHALL log it as a security event but still process the token request
- WHERE AI-powered anomaly detection is available THEN the system SHALL flag high-risk reasons for human review

#### EDGE-004: Revoked Parent Token in Delegation Chain
**Scenario:** A parent agent token is revoked while child agents are active
**Requirement:**
- WHEN a parent token is revoked THEN all child tokens in the delegation chain SHALL be revoked within 1 second
- IF child tokens are cached in ETS THEN cache invalidation SHALL propagate immediately
- WHERE child agents attempt to use revoked tokens THEN they SHALL receive HTTP 401 with error "parent_token_revoked"

### 5.2 Constraints

#### CONST-001: Programming Language
- Thalamus core SHALL be implemented in Elixir 1.17+ on OTP 27+
- External SDKs MAY be implemented in any language (Python, TypeScript, Go, Rust)

#### CONST-002: Database
- PostgreSQL 16+ SHALL be used for persistent storage (users, clients, tokens, audit logs)
- ETS SHALL be used for high-performance in-memory caching (no Redis dependency)

#### CONST-003: OAuth2 Compliance
- The system SHALL comply with RFC 6749 (OAuth 2.0), RFC 7662 (Token Introspection), RFC 7009 (Token Revocation)
- The system SHALL support PKCE (RFC 7636) for Authorization Code flow
- The system SHALL optionally implement IETF draft AAuth when spec stabilizes

#### CONST-004: Breaking Changes
- Major API changes SHALL follow semantic versioning (MAJOR.MINOR.PATCH)
- Deprecated endpoints SHALL be supported for 6 months before removal

---

## 6. Success Metrics

### 6.1 Technical Metrics

1. **Latency SLA:** 95% of token generation requests complete in < 4ms (p95)
2. **Throughput:** Single node sustains 10,000 RPS with CPU < 70%
3. **Cache Hit Rate:** ETS cache hit rate > 95% for token introspection
4. **Error Rate:** < 0.1% of requests result in 5xx errors
5. **Uptime:** 99.9% availability (< 8.76 hours downtime/year)

### 6.2 Business Metrics

1. **Cost Efficiency:** $333/month for 10M tokens vs. $10k-$50k with competitors (97%+ savings)
2. **Time to Integration:** Developers integrate Thalamus in < 30 minutes using SDK
3. **Adoption:** 10 early adopter companies deploy Thalamus in production by Q2 2026
4. **Developer Satisfaction:** NPS > 40 based on SDK usability survey

### 6.3 Security Metrics

1. **Vulnerability Remediation:** Critical vulnerabilities patched within 48 hours
2. **Audit Compliance:** 100% of authentication events logged and retained for 90 days
3. **Zero Breaches:** No security incidents resulting in token leakage during first year

---

## 7. Out of Scope (Future Phases)

The following features are explicitly OUT OF SCOPE for initial release:

1. **Social Login Providers (Google, GitHub, Microsoft):** Focus is M2M, not human B2C authentication
2. **SAML Support:** OAuth2/OIDC only
3. **Built-in MFA for Humans:** Agents don't need TOTP; security is scope-based
4. **Admin UI for Organization Management:** API-first; CLI tools for admin operations
5. **AI-Powered Anomaly Detection:** Manual audit logs in v1; ML-based detection in v2
6. **Geo-Distributed Deployment:** Single-region deployment in v1; multi-region in v2

---

## 8. Risks and Mitigations

### RISK-001: ETS Cache Invalidation Lag
**Risk:** ETS is node-local; revoked tokens may remain cached on other nodes for up to 60 seconds
**Mitigation:** Use Phoenix PubSub to broadcast cache invalidation events across nodes

### RISK-002: PostgreSQL Connection Pool Saturation
**Risk:** High write load (audit logs) may saturate connection pool
**Mitigation:** Use separate connection pool for audit log writes; batch log inserts

### RISK-003: Elixir Talent Shortage
**Risk:** Hiring Elixir engineers is harder than hiring for Node.js/Python
**Mitigation:** Provide comprehensive onboarding docs; abstract complexity behind SDKs so most developers never touch Elixir

### RISK-004: JWT Secret Key Rotation
**Risk:** Rotating signing keys requires careful coordination to avoid invalidating active tokens
**Mitigation:** Support multiple active keys simultaneously (key ID in JWT header); retire old keys after TTL expires

---

## 9. Appendix: EARS Format Reference

This document uses the EARS (Enhanced At a Glance Requirements Specification) format for acceptance criteria.

### Keywords:
- **WHEN [event]:** Describes a triggering event
- **IF [condition]:** Describes a precondition that must be true
- **WHILE [state]:** Describes behavior during a specific state
- **WHERE [context]:** Describes a specific context or location
- **SHALL:** Indicates a mandatory requirement
- **SHOULD:** Indicates a recommended but not mandatory requirement
- **MAY:** Indicates an optional feature

### Example:
> WHEN an agent requests a token THEN the system SHALL generate it in <5ms
> IF the client credentials are invalid THEN the system SHALL return HTTP 401
> WHILE under load (>10k RPS) THEN the system SHALL maintain p99 latency <5ms
> WHERE the organization_id differs THEN the system SHALL enforce access isolation

---

**Document End**

**Next Steps:**
1. Review and approve this requirements document
2. Proceed to Phase 2: Design (Architecture + Mermaid Diagrams)
3. Proceed to Phase 3: Tasks (Implementation Plan with checkboxes)
