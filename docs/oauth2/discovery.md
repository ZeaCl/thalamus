# Discovery & JWKS

OpenID Connect Discovery and JSON Web Key Set endpoints for service discovery and JWT verification.

---

## OIDC Discovery

```
GET /.well-known/openid-configuration
```

Returns server metadata per [OpenID Connect Discovery 1.0](https://openid.net/specs/openid-connect-discovery-1_0.html).

### Request

```bash
curl http://localhost:4000/.well-known/openid-configuration
```

No authentication required.

### Response

```json
{
  "issuer": "http://localhost:4000",
  "authorization_endpoint": "http://localhost:4000/oauth/authorize",
  "token_endpoint": "http://localhost:4000/oauth/token",
  "userinfo_endpoint": "http://localhost:4000/oauth/userinfo",
  "introspection_endpoint": "http://localhost:4000/oauth/introspect",
  "revocation_endpoint": "http://localhost:4000/oauth/revoke",

  "response_types_supported": ["code"],
  "grant_types_supported": [
    "authorization_code",
    "client_credentials",
    "refresh_token"
  ],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256"],

  "scopes_supported": [
    "openid", "profile", "email", "address", "phone", "offline_access"
  ],

  "token_endpoint_auth_methods_supported": [
    "client_secret_basic",
    "client_secret_post"
  ],

  "claims_supported": [
    "sub", "name", "email", "email_verified",
    "phone_number", "phone_number_verified", "updated_at"
  ],

  "code_challenge_methods_supported": ["S256", "plain"],
  "response_modes_supported": ["query", "fragment"],
  "service_documentation": "http://localhost:4000/docs",
  "ui_locales_supported": ["en"]
}
```

### Key Fields

| Field | Description |
|---|---|
| `issuer` | Authorization server URL |
| `authorization_endpoint` | OAuth2 `/authorize` endpoint |
| `token_endpoint` | OAuth2 `/token` endpoint |
| `userinfo_endpoint` | OpenID Connect UserInfo |
| `introspection_endpoint` | RFC 7662 introspection |
| `revocation_endpoint` | RFC 7009 revocation |
| `response_types_supported` | Only `code` (implicit flow disabled) |
| `grant_types_supported` | `authorization_code`, `client_credentials`, `refresh_token` |
| `code_challenge_methods_supported` | PKCE: `S256` and `plain` |
| `token_endpoint_auth_methods_supported` | `client_secret_basic`, `client_secret_post` |
| `id_token_signing_alg_values_supported` | `RS256` |

> **Not supported**: `implicit` grant, `password` grant (deprecated), `token`/`id_token` response types.

---

## JWKS Endpoint

```
GET /.well-known/jwks.json
```

Returns the public RSA key used for JWT signature verification. Resource servers (e.g., Cerebelum) use this to validate JWT tokens issued by Thalamus.

### Request

```bash
curl http://localhost:4000/.well-known/jwks.json
```

No authentication required.

### Response

```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "thalamus-signing-key",
      "use": "sig",
      "alg": "RS256",
      "n": "...",
      "e": "AQAB"
    }
  ]
}
```

### Caching

The JWKS response includes a `Cache-Control: public, max-age=86400` header. Clients should cache the keys for up to 24 hours.

---

## Usage in Resource Servers

Resource servers (like Cerebelum) use the JWKS endpoint to validate JWT tokens:

```python
import requests
from jose import jwt
from jose.jwk import RSAKey

# 1. Fetch JWKS
response = requests.get("http://localhost:4000/.well-known/jwks.json")
jwks = response.json()

# 2. Build RSA key from JWK
key = RSAKey(jwks["keys"][0], algorithm="RS256")

# 3. Verify JWT
payload = jwt.decode(
    access_token,
    key,
    algorithms=["RS256"],
    audience="cerebelum"
)
```

---

## Base URL

The base URL for generated links is determined from:

1. **Configuration**: `config :thalamus, host: "auth.zea.cl"`  
2. **Request fallback**: Uses the `Host` header from the incoming request

The port is included only for non-standard ports (i.e., not 80/443).

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [UserInfo Endpoint](userinfo.md) — Get user data from a token
- [Token Introspection](token-introspection.md) — Validate tokens
