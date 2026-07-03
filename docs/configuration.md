# Configuration

Thalamus configuration covers email delivery, organization plans, OAuth2 scopes, and environment variables.

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `DATABASE_URL` | ✅ | — | Ecto connection string |
| `SECRET_KEY_BASE` | ✅ | — | Phoenix secret key (64+ chars) |
| `PHX_HOST` | ❌ | `localhost` | Host for URL generation |
| `PORT` | ❌ | `4000` | HTTP port |
| `POOL_SIZE` | ❌ | `10` | DB connection pool |

---

## Email Configuration

Uses Swoosh for email delivery. See [Email Guide](#) for full details.

### Development

Emails captured locally at `http://localhost:4000/dev/mailbox`. No config needed.

### Production (SendGrid)

```bash
export SMTP_RELAY="smtp.sendgrid.net"
export SMTP_USERNAME="apikey"
export SMTP_PASSWORD="your-sendgrid-api-key"
export SMTP_PORT="587"
export SMTP_TLS="always"
export SMTP_AUTH="always"
export FROM_EMAIL="noreply@yourdomain.com"
export FROM_NAME="Thalamus"
```

### Other Providers

| Provider | SMTP Relay | Port |
|---|---|---|
| Mailgun | `smtp.mailgun.org` | 587 |
| Amazon SES | `email-smtp.us-east-1.amazonaws.com` | 587 |
| Postmark | `smtp.postmarkapp.com` | 587 |

---

## Organization Plans

Configurable subscription plans. No code changes needed.

### Default Plans

| Plan | Max Users | API Calls/Month | MFA | SSO | Audit Logs |
|---|---|---|---|---|---|
| `free` | 5 | 10,000 | ❌ | ❌ | 7 days |
| `starter` | 25 | 100,000 | ❌ | ❌ | 30 days |
| `pro` | 100 | 1,000,000 | ✅ | ❌ | 90 days |
| `enterprise` | Unlimited | Unlimited | ✅ | ✅ | 365 days |

### Custom Plans

```elixir
# config/config.exs
config :thalamus, :organization_plans, %{
  "free" => %{
    max_users: 10,
    api_calls_per_month: 50_000,
    mfa_required: false,
    sso_enabled: false,
    audit_log_retention_days: 30,
    support_level: "community"
  },
  "growth" => %{
    max_users: 50,
    api_calls_per_month: 500_000,
    mfa_required: true,
    sso_enabled: true,
    audit_log_retention_days: 90,
    support_level: "email"
  }
}
```

---

## OAuth2 Scopes

Custom scopes are configurable:

```elixir
# config/config.exs
config :thalamus, :oauth2_scopes, %{
  custom_scopes: [
    "api:read",
    "api:write",
    "data:read",
    "data:write",
    "webhooks:manage",
    "billing:read",
    "billing:write"
  ],
  restricted_scopes: [
    "api:admin",
    "billing:write",
    "offline_access"
  ]
}
```

**Standard OIDC scopes** (`openid`, `profile`, `email`, `address`, `phone`, `offline_access`) are always available and cannot be removed.

---

## Feature Flags

```elixir
# config/config.exs
config :thalamus, :feature_flags, %{
  agent_tokens_enabled: true,
  saml_sso_enabled: false,
  mfa_required: false
}
```

| Flag | Default | Description |
|---|---|---|
| `agent_tokens_enabled` | `true` | Enable `/oauth/agent-token` endpoint |
| `saml_sso_enabled` | `false` | Enable SAML SSO |
| `mfa_required` | `false` | Require MFA for all users |

---

## Rate Limiting

Configure per-pipeline limits:

```elixir
# In router.ex pipelines
plug ThalamusWeb.Plugs.RateLimiter,
  limit: 1000,       # requests
  window: 60_000,    # milliseconds (1 minute)
  key: :ip_address   # :ip_address or :user_id
```

**Production recommendations:**

| Pipeline | Limit | Window |
|---|---|---|
| `api` (public) | 1000 | 60s |
| `oauth2_browser` | 20 | 60s |
| `oauth2_api` | 100 | 60s |
| `authenticated_api` | 5000 | 60s |
| `registration` | 5 | 60s |

---

## CORS

```elixir
# config/config.exs
config :thalamus, :cors_origins, [
  "https://app.zea.cl",
  "https://dashboard.zea.cl"
]
```

---

## Security Headers

Enabled by default via `ThalamusWeb.Plugs.SecurityHeaders`:

| Header | Value |
|---|---|
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `X-XSS-Protection` | `1; mode=block` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy` | Configurable per endpoint |

---

## Host Configuration

```elixir
# config/prod.exs
config :thalamus, host: "auth.zea.cl"
```

Used by the OIDC Discovery endpoint to generate correct URLs in `issuer`, `authorization_endpoint`, etc.

---

## Database

```elixir
# config/runtime.exs
config :thalamus, Thalamus.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
```

---

## See Also

- [Deployment Guide](deployment.md) — Production deployment
- [Architecture Overview](../architecture/overview.md) — System design
- [OAuth2 Overview](../oauth2/overview.md) — OAuth2 configuration
