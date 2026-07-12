# Architecture Overview

Thalamus follows **Clean Architecture** with strict SOLID principles. Dependencies flow inward: outer layers depend on inner layers, never the reverse.

---

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Presentation Layer (lib/thalamus_web/)                     │
│  Controllers, Plugs, Router, LiveView, HTML templates       │
├─────────────────────────────────────────────────────────────┤
│  Application Layer (lib/thalamus/application/)              │
│  Use Cases, DTOs, Ports (behaviours)                        │
├─────────────────────────────────────────────────────────────┤
│  Domain Layer (lib/thalamus/domain/)                        │
│  Entities, Value Objects, Domain Services                   │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure Layer (lib/thalamus/infrastructure/)        │
│  Repositories, Ecto Schemas, Adapters, External Services    │
└─────────────────────────────────────────────────────────────┘
```

---

## Domain Layer

Pure business logic with zero external dependencies.

### Entities (9)

| Entity | File | Description |
|---|---|---|
| `User` | `user.ex` | User account with auth state |
| `Organization` | `organization.ex` | Multi-tenant organization |
| `OAuth2Client` | `oauth2_client.ex` | Registered OAuth2 application |
| `AgentToken` | `agent_token.ex` | AI agent token with task scoping |
| `Role` | `role.ex` | RBAC role with scopes |
| `Secret` | `secret.ex` | Encrypted secret storage |
| `AdminApiKey` | `admin_api_key.ex` | Service-to-service API key |
| `PersonalAccessToken` | `personal_access_token.ex` | User PAT for CLI/scripts |
| `SamlIdentityProvider` | `saml_identity_provider.ex` | SAML IdP configuration |

### Value Objects (21)

| Category | Value Objects |
|---|---|
| **Auth** | `AccessToken`, `AuthorizationCode`, `RefreshToken`, `PasswordHash`, `PKCEChallenge` |
| **Identity** | `UserId`, `Email`, `ClientId`, `ClientSecret`, `OrganizationId` |
| **OAuth2** | `GrantType`, `Scope`, `RedirectUri` |
| **Agents** | `AgentType`, `TaskId`, `DelegationChain` |
| **RBAC** | `Permission`, `MFAMethod` |
| **SAML** | `SamlEntityId`, `SamlNameId`, `SamlAttributeMapping` |
| **Billing** | `Plan` |

All value objects:
- Validate on creation (`{:ok, value}` or `{:error, reason}`)
- Are immutable
- Implement `String.Chars` and `Jason.Encoder`

---

## Application Layer

Orchestrates business workflows using domain entities and infrastructure ports.

### Use Cases (19)

| Category | Use Cases |
|---|---|
| **Auth** | `AuthenticateUser`, `AuthenticateUserViaSaml` |
| **Tokens** | `GenerateTokens`, `ValidateToken`, `CachedValidateToken`, `GenerateAgentToken`, `RevokeAgentToken` |
| **RBAC** | `AssignRole`, `RevokeRole`, `CreateRole`, `UpdateRole`, `DeleteRole`, `ListRoles`, `GetUserRoles`, `GetEffectiveScopes` |
| **Agents** | `ValidateStepAuthorization`, `ResolveAgentSecret` |
| **Secrets** | `ManageSecrets` |

Pattern: every use case has `execute(request, deps)` where `deps` is a map of port implementations.

### Ports / Behaviours (14)

| Port | Purpose |
|---|---|
| `UserRepository` | User persistence |
| `TokenRepository` | Token storage |
| `OAuth2ClientRepository` | Client app persistence |
| `OrganizationRepository` | Organization persistence |
| `RoleRepository` | Role persistence |
| `AdminApiKeyRepository` | API key storage |
| `AgentTokenRepository` | Agent token storage |
| `SecretRepository` | Secret storage |
| `SamlIdentityProviderRepository` | SAML IdP persistence |
| `AuditLogger` | Security event logging |
| `EmailService` | Email delivery |
| `CacheService` | Caching (Redis/Cachex) |
| `FileUploadService` | File/avatar storage |
| `CompliancePolicy` | Organization compliance rules |

---

## Infrastructure Layer

Implements application ports with concrete technologies.

### Repositories (10 PostgreSQL implementations)

| Repository | Port |
|---|---|
| `PostgreSQLUserRepository` | `UserRepository` |
| `PostgreSQLTokenRepository` | `TokenRepository` |
| `PostgreSQLOAuth2ClientRepository` | `OAuth2ClientRepository` |
| `PostgreSQLOrganizationRepository` | `OrganizationRepository` |
| `PostgreSQLRoleRepository` | `RoleRepository` |
| `PostgreSQLAdminApiKeyRepository` | `AdminApiKeyRepository` |
| `PostgreSQLAgentTokenRepository` | `AgentTokenRepository` |
| `PostgreSQLSecretRepository` | `SecretRepository` |
| `PostgreSQLSamlIdentityProviderRepository` | `SamlIdentityProviderRepository` |
| `PostgreSQLPersonalAccessTokenRepository` | PAT storage |

### Ecto Schemas (17)

Maps domain entities to database tables in `lib/thalamus/infrastructure/persistence/schemas/`.

| Schema | Table | Purpose |
|---|---|---|
| `UserDomainRoleSchema` | `user_domain_roles` | Multi-tenant RBAC: asigna scopes a usuarios por organización y dominio |

`UserDomainRoleSchema` es la base de la autorización multi-tenant. Cada fila asigna un `domain` (ej. `"funds"`), un `role` (ej. `"gp_admin"`), y un array de `scopes` (ej. `["funds:read", "funds:write"]`) a un usuario dentro de una organización. Estos roles se serializan en el JWT como el claim `domain_roles` y son validados por servicios downstream sin consultar la DB.

### Adapters

| Adapter | Purpose |
|---|---|
| `RedisCacheAdapter` | Token introspection cache |
| `CachexCacheAdapter` | In-memory cache fallback |
| `AuditLoggerImpl` | Database-backed audit logging |
| `SamlyAssertionValidator` | SAML assertion validation |

---

## Presentation Layer

### Controllers (32)

| Group | Controllers | Endpoints |
|---|---|---|
| **OAuth2** | 8 | authorize, token, agent-token, userinfo, introspect, revoke, discovery, jwks |
| **API Public** | 4 | health, login, register, password |
| **API Auth** | 9 | users, organizations, roles, MFA, secrets, domains, PATs, audit-logs, authorization |
| **API Internal** | 3 | secrets resolve, agent-token, agent-config |
| **Admin** | 1 | admin API keys |
| **Browser** | 3 | page, session, registration |
| **SAML** | 1 | init, acs, metadata |
| **Docs** | 1 | documentation pages |

### Plugs (8)

| Plug | Pipeline | Purpose |
|---|---|---|
| `CORS` | api, oauth2 | Cross-origin headers |
| `SecurityHeaders` | browser, api, oauth2 | CSP, HSTS, X-Frame-Options |
| `RateLimiter` | all | Configurable per-pipeline limits |
| `AgentTokenRateLimiter` | authenticated_api | Agent-specific rate limiting |
| `AuthenticateToken` | authenticated_api | JWT Bearer validation |
| `APIAuth` | api_auth, super_admin | JWT or API Key auth |
| `RequireSuperAdmin` | super_admin | Role check |
| `RequireScope` | authenticated_api | Scope check |

---

## Pipelines & Rate Limits

| Pipeline | Auth | Rate Limit | Key |
|---|---|---|---|
| `browser` | Session | — | — |
| `api` | None | 1000/min | IP |
| `oauth2_browser` | Session | 20/min | IP |
| `oauth2_api` | None | 1000/min | IP |
| `authenticated_api` | JWT | 5000/min | user_id |
| `api_auth` | JWT/API Key | 5000/min | user_id |
| `super_admin` | JWT + role | 1000/min | user_id |
| `internal_api` | None | — | — |
| `registration` | None | 5/min | IP |

---

## Dependency Injection

Dependencies are injected at the controller level via `DependencyBuilder`:

```elixir
# lib/thalamus/dependency_builder.ex
def build_for_web(conn) do
  %{
    user_repository: PostgreSQLUserRepository,
    token_repository: PostgreSQLTokenRepository,
    audit_logger: AuditLoggerImpl,
    # ...
  }
end
```

This enables:
- **Testing**: Swap real repos for mocks via Mox
- **Flexibility**: Change implementations without touching domain logic
- **Portability**: Each layer is independently deployable

---

## Key Design Decisions

1. **No implicit grant** — Disabled for security (RFC 6749 §10)
2. **Password grant deprecated** — Returns error, recommends PKCE
3. **PKCE required** for authorization_code — `S256` by default
4. **First-party auto-approval** — `platform_web`, `thalamus_cli`, `app_*` bypass consent
5. **Agent tokens feature-flagged** — `agent_tokens_enabled` gates the endpoint
6. **Refresh token rotation** — New refresh token issued on each use
7. **Constant-time comparison** — `Plug.Crypto.secure_compare` for secrets
8. **Audit logging** — All security events logged with full metadata
