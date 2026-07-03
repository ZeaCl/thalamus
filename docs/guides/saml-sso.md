# SAML SSO

Enterprise Single Sign-On via SAML 2.0. Configure an Identity Provider (IdP) per organization and let users authenticate through their corporate SSO.

---

## Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/auth/saml/init` | Initiate SP-initiated SAML flow |
| `POST` | `/auth/saml/acs` | Assertion Consumer Service (IdP callback) |
| `GET` | `/auth/saml/metadata/:id` | SP metadata XML for IdP configuration |

**Pipeline:** `oauth2_api` — No auth required.

---

## Flow

```
1. User visits /login, enters email
2. System detects SAML domain → redirects to /auth/saml/init?email=user@corp.com
3. Thalamus looks up SAML config by email domain
4. User is redirected to corporate IdP login page
5. User authenticates with IdP
6. IdP POSTs SAML assertion to /auth/saml/acs
7. Thalamus validates assertion, creates/finds user, issues session
8. User is redirected to dashboard
```

---

## Initiate SAML Flow

```
GET /auth/saml/init?email=user@contoso.com
```

Detects the user's organization by email domain and redirects to the configured IdP.

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `email` | ✅ | User email (domain used to find IdP config) |

**Response:** `302 Redirect` to the IdP's SSO URL with a SAML AuthnRequest.

---

## Assertion Consumer Service

```
POST /auth/saml/acs
Content-Type: application/x-www-form-urlencoded

SAMLResponse=base64encodedassertion&RelayState=org_abc123
```

Receives the SAML assertion from the IdP after user authentication.

**Parameters (form-encoded):**

| Parameter | Required | Description |
|---|---|---|
| `SAMLResponse` | ✅ | Base64-encoded SAML assertion |
| `RelayState` | ❌ | Organization ID for verification |

**On success:** `302 Redirect` to `/` with session cookie.

**On failure:** `302 Redirect` to `/login` with error message.

---

## SP Metadata

```
GET /auth/saml/metadata/:id
```

Returns the Service Provider metadata XML that the IdP administrator uses to configure the trust relationship.

**Response:** `application/xml` with SP entity descriptor.

---

## SAML Configuration (Organization)

SAML is configured per organization via the API:

### Get SAML Config

```bash
GET /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
```

### Update SAML Config

```bash
PUT /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "entity_id": "https://contoso.com/saml",
  "acs_url": "https://contoso.com/saml/acs",
  "certificate": "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
  "name": "Contoso SSO",
  "email_domains": ["contoso.com"],
  "enabled": true,
  "attribute_mapping": {
    "email": "email",
    "name": "displayName",
    "first_name": "givenName",
    "last_name": "sn"
  }
}
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `entity_id` | ✅ | IdP entity ID |
| `acs_url` | ✅ | IdP SSO URL |
| `certificate` | ✅ | IdP x509 signing certificate (PEM) |
| `name` | ✅ | Display name for the IdP |
| `email_domains` | ✅ | Email domains that use this IdP |
| `enabled` | ❌ | Enable/disable SAML |
| `attribute_mapping` | ❌ | Map SAML attributes to user fields |

### Delete SAML Config

```bash
DELETE /api/organizations/org_abc123/saml-config
Authorization: Bearer eyJhbGciOi...
```

---

## SAML Entity Model

| Field | Source | Description |
|---|---|---|
| `entity_id` | `SamlEntityId` VO | IdP entity identifier |
| `acs_url` | Configuration | Assertion Consumer Service URL |
| `certificate` | Configuration | x509 certificate for signature verification |
| `name` | Configuration | Human-readable IdP name |
| `email_domains` | Configuration | Domains routed to this IdP |
| `attribute_mapping` | `SamlAttributeMapping` VO | Maps IdP attributes → user fields |
| `name_id_format` | `SamlNameId` VO | NameID format (default: `emailAddress`) |

---

## Feature Flag

SAML SSO is gated behind a feature flag:

```elixir
config :thalamus, :feature_flags, %{
  saml_sso_enabled: true
}
```

---

## See Also

- [Organizations API](../api/organizations.md) — SAML config management
- [Authentication API](../api/authentication.md) — Standard login flow
- [Configuration](configuration.md) — Feature flags and env vars
- [Architecture Overview](../architecture/overview.md) — SamlIdentityProvider entity
