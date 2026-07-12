# Getting Started

Thalamus is used in different ways depending on who you are and what you're building. Pick your path:

---

## 🟦 Dev: Integrating an App

You have a web app, mobile app, or backend service and need authentication.

### Quickest path

**If your app is in the ZEA ecosystem** and Thalamus is already running at `auth.zea.cl`:

#### 1. Get credentials

Ask your admin for:
- `client_id` and `client_secret`
- `organization_id`

Or [auto-register your service](guides/admin-api-keys.md) if you have an API key.

#### 2. Pick your OAuth2 flow

| Your app type | Use this flow |
|---|---|
| Web app (React, Next.js, Phoenix) | [Authorization Code + PKCE](oauth2/authorization-code.md) |
| Mobile app (iOS, Android) | [Authorization Code + PKCE](oauth2/authorization-code.md) |
| Backend/CLI/script | [Client Credentials (M2M)](oauth2/client-credentials.md) |

#### 3. Code it

```bash
# Authorization Code flow
curl "https://auth.zea.cl/oauth/authorize?response_type=code&client_id=client_xxx&redirect_uri=https://app.com/callback&scope=openid+profile+email&code_challenge=CHALLENGE&code_challenge_method=S256&state=RANDOM"

# Exchange code for token
curl -X POST https://auth.zea.cl/oauth/token \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -d "grant_type=authorization_code&code=ac_xxx&redirect_uri=https://app.com/callback&code_verifier=VERIFIER"

# Use the token
curl -H "Authorization: Bearer at_xxx" https://auth.zea.cl/api/users
```

#### 4. Dive deeper

- [Full OAuth2 overview](oauth2/overview.md) — All grants + scopes
- [API reference](api/rest.md) — All REST endpoints
- [Tutorials](tutorials/README.md) — Step-by-step examples by technology

---

## 🤖 AI Agent

You're an AI agent (or building one) that needs to act on behalf of users with task-scoped permissions.

### Quickest path

#### 1. Understand agent tokens

Agent tokens are different from user tokens — they're task-scoped, time-limited, and track full delegation chains. Read the [Agent Overview](agents/overview.md).

#### 2. Get your token

```bash
curl -X POST https://auth.zea.cl/oauth/agent-token \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "client_xxx",
    "client_secret": "secret_xxx",
    "organization_id": "org_abc",
    "delegator_user_id": "user_xyz",
    "agent_type": "autonomous",
    "task_description": "Analyze Q4 sales data",
    "scope": "data:read report:generate"
  }'
```

#### 3. Validate each step

Before executing any operation, Cerebelum validates your token:

```bash
curl -X POST https://auth.zea.cl/api/authorization/validate-step \
  -H "Authorization: Bearer at_xxx" \
  -H "Content-Type: application/json" \
  -d '{"step_name": "send_email", "required_scopes": ["email:send"]}'
```

#### 4. Dive deeper

- [Agent CLI Reference](agents/cli.md) — All agent endpoints
- [Skills Catalog](agents/skills.md) — Available scopes by agent type
- [Agent Token Spec](oauth2/agent-tokens.md) — Full token endpoint documentation

---

## 🟢 DevOps: Deploy On-Prem

You want to run Thalamus in your own infrastructure.

### Quickest path

#### 1. Requirements

- Elixir 1.19+ / Erlang 27+
- PostgreSQL 12+
- Redis 7+ (optional, recommended)

#### 2. Install

```bash
git clone <thalamus-repo>
cd thalamus
mix deps.get
mix ecto.create && mix ecto.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

#### 3. Or Docker

```bash
docker compose up -d
docker compose exec thalamus bin/thalamus eval "Thalamus.Release.migrate()"
```

#### 4. Configure

Set environment variables and pick your plan configuration. See [Configuration](configuration.md).

#### 5. Dive deeper

- [Deployment Guide](deployment.md) — Production, reverse proxy, ZEA Platform
- [Configuration](configuration.md) — Email, plans, feature flags, rate limits
- [Architecture Overview](architecture/overview.md) — System design

---

## 🟣 Admin: Manage an Instance

You administer users, organizations, OAuth2 clients, and roles in an existing Thalamus deployment.

### Quickest path

#### 1. Get admin access

Login at `/login` with your admin credentials, or use an [Admin API Key](guides/admin-api-keys.md) for API access.

#### 2. Manage resources

| Task | Guide |
|---|---|
| Create/manage users | [Users API](api/users.md) |
| Manage organizations | [Organizations API](api/organizations.md) |
| Register OAuth2 clients | [Clients API](api/clients.md) |
| Configure roles & scopes | [Roles API](api/roles.md) |
| Enable MFA for users | [MFA API](api/mfa.md) |
| Set up SAML SSO | [SAML SSO Guide](guides/saml-sso.md) |
| Export audit logs | [Audit Logs API](api/audit-logs.md) |

#### 3. Dive deeper

- [API Reference](api/rest.md) — All endpoints
- [Configuration](configuration.md) — Plans, email, feature flags

---

## 🟡 Architect: Understand the System

You want to understand how Thalamus is built, its design decisions, and how to extend it.

### Quickest path

1. [Architecture Overview](architecture/overview.md) — Clean Architecture, 4 layers, 9 entities, 21 VOs, 19 use cases, 14 ports, 8 plugs
2. [OAuth2 Overview](oauth2/overview.md) — Grant types, PKCE, token lifecycle, first-party auto-approval
3. [CLAUDE.md](../CLAUDE.md) — Coding agent instructions with patterns and conventions

---

## Environment Reference

| Environment | URL | Auth |
|---|---|---|
| ZEA Cloud (production) | `https://auth.zea.cl` | JWT via OAuth2 |
| Local development | `http://auth.zea.localhost` | JWT via OAuth2 |
| Internal (same network) | `http://thalamus:4000` | No auth for `/api/internal/*` |
