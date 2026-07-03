# Thalamus Documentation

Thalamus is an OAuth2 / OpenID Connect authentication and authorization service. Use it **on-premise** (your own infrastructure) or as the **ZEA Cloud** auth service at `auth.zea.cl`.

---

## What are you trying to do?

| I want to... | Start here |
|---|---|
| 🟦 **Add login to my app** (web, mobile, backend) | [Getting Started → Dev](getting-started.md#-dev-integrating-an-app) |
| 🤖 **Act as an AI agent / build agents** | [Getting Started → Agent](getting-started.md#-ai-agent) |
| 🟢 **Deploy Thalamus on my own infra** | [Getting Started → DevOps](getting-started.md#-devops-on-prem) |
| 🟣 **Administer users, orgs, clients** | [Getting Started → Admin](getting-started.md#-admin) |
| 🟡 **Understand the architecture** | [Architecture Overview](architecture/overview.md) |

---

## OAuth2 & OpenID Connect

| Guide | Description |
|---|---|
| [Overview](oauth2/overview.md) | Grants, PKCE, scopes, token lifecycle |
| [Authorization Code + PKCE](oauth2/authorization-code.md) | Full flow: authorize → consent → token |
| [Client Credentials (M2M)](oauth2/client-credentials.md) | Machine-to-machine auth |
| [Token Introspection](oauth2/token-introspection.md) | Validate tokens (RFC 7662) |
| [Token Revocation](oauth2/token-revocation.md) | Revoke tokens (RFC 7009) |
| [UserInfo Endpoint](oauth2/userinfo.md) | OpenID Connect user data |
| [Discovery & JWKS](oauth2/discovery.md) | OIDC Discovery + public keys |
| [Agent Tokens](oauth2/agent-tokens.md) | AI agent tokens with task-scoping |

---

## Agents

| Guide | Description |
|---|---|
| [Agent Overview](agents/overview.md) | How agents authenticate and act on behalf of users |
| [CLI Reference](agents/cli.md) | Endpoints for token management and step authorization |
| [Skills Catalog](agents/skills.md) | Available scopes by agent type, validation flow |

---

## REST API

| Guide | Endpoints |
|---|---|
| [Overview](api/rest.md) | Auth headers, pagination, rate limits, response format |
| [Authentication](api/authentication.md) | Login, register, email verify, password reset |
| [Users](api/users.md) | CRUD, avatar, password change |
| [Organizations](api/organizations.md) | CRUD, members, SAML config |
| [OAuth2 Clients](api/clients.md) | CRUD, secret rotation, add-redirect-uri, validate |
| [Roles (RBAC)](api/roles.md) | CRUD roles, assign/revoke, effective scopes |
| [MFA](api/mfa.md) | TOTP setup, verify, disable, backup codes |
| [Secrets](api/secrets.md) | CRUD secrets, internal resolve |
| [Domains](api/domains.md) | Domain-agnostic RBAC |
| [Personal Access Tokens](api/personal-access-tokens.md) | CRUD PATs |
| [Audit Logs](api/audit-logs.md) | Export CSV/JSON |

---

## Operations

| Guide | Description |
|---|---|
| [Deployment](deployment.md) | Docker, production, reverse proxy |
| [Configuration](configuration.md) | Email, plans, scopes, feature flags, env vars |
| [Admin API Keys](guides/admin-api-keys.md) | Service-to-service authentication |
| [SAML SSO](guides/saml-sso.md) | Enterprise single sign-on |

---

## Architecture

| Guide | Description |
|---|---|
| [Architecture Overview](architecture/overview.md) | Clean Architecture, 4 layers, entities, ports, plugs |

---

## Tutorials

Step-by-step walkthroughs for integrating apps with Thalamus:

| Tutorial | Description |
|---|---|
| [Complete Integration](tutorials/01-integracion-completa.md) | End-to-end integration from scratch |
| [Frontend Web](tutorials/02-frontend-web.md) | React/Next.js + Authorization Code + PKCE |
| [Backend API](tutorials/03-backend-api.md) | Node.js/Python + Client Credentials (M2M) |
| [Mobile App](tutorials/04-mobile-app.md) | Authorization Code + PKCE + deep linking |
| [Agent Tokens](tutorials/11-agent-tokens.md) | AI agent token flow |

---

## Reference

| Resource | Description |
|---|---|
| [OpenAPI Spec](OPENAPI_SPEC.yaml) | Full API specification (OpenAPI 3.0) |
| [CLAUDE.md](../CLAUDE.md) | Coding agent instructions |
