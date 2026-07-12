# Authorization Code Flow + PKCE

The most secure OAuth2 flow for web and mobile applications. Uses PKCE (RFC 7636) to prevent authorization code interception.

---

## Flow Overview

```
User ──→ App ──→ GET /oauth/authorize ──→ Login screen ──→ Consent screen
                  ?response_type=code
                  &client_id=...
                  &redirect_uri=...
                  &scope=...
                  &code_challenge=...
                  &code_challenge_method=S256
                  &state=random

User approves ──→ 302 redirect to redirect_uri?code=ac_xxx&state=random

App ──→ POST /oauth/token
         grant_type=authorization_code
         &code=ac_xxx
         &redirect_uri=...
         &client_id=...
         &client_secret=...
         &code_verifier=...

App ←── { access_token, refresh_token, expires_in, scope }
```

---

## Step 1: Generate PKCE Parameters

```bash
# Generate code_verifier (43-128 random chars)
CODE_VERIFIER=$(openssl rand -base64 48 | tr -d '=' | tr '+/' '-_')

# Generate code_challenge (SHA256 + base64url)
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '+/' '-_')

echo "code_verifier:  $CODE_VERIFIER"
echo "code_challenge: $CODE_CHALLENGE"
```

---

## Step 2: Request Authorization (GET)

```
GET /oauth/authorize?response_type=code&client_id=client_xxx&redirect_uri=https://app.com/callback&scope=openid%20profile%20email&code_challenge=AsdF...&code_challenge_method=S256&state=xYz123
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `response_type` | ✅ | Must be `code` |
| `client_id` | ✅ | OAuth2 client ID |
| `redirect_uri` | ⚠️ | Must match one of the client's registered URIs. If omitted, uses the first registered URI |
| `scope` | ❌ | Space-separated scopes. If omitted, uses all client's allowed scopes |
| `code_challenge` | ⚠️ | PKCE code challenge (strongly recommended) |
| `code_challenge_method` | ❌ | `S256` (default) or `plain` |
| `state` | ⚠️ | Opaque value returned as-is; use for CSRF protection |

**What happens:**
1. User is redirected to login if not authenticated
2. After login, user sees consent screen showing:
   - Client name
   - Requested scopes
   - Redirect URI
3. User clicks **Approve** or **Deny**

**First-party clients** (`platform_web`, `thalamus_cli`, `app_*`) **skip the consent screen** and auto-approve.

### Success Response

```
HTTP/1.1 302 Found
Location: https://app.com/callback?code=ac_abc123def456&state=xYz123
Cache-Control: no-store
Pragma: no-cache
```

### Error Response

```
HTTP/1.1 302 Found
Location: https://app.com/callback?error=access_denied&error_description=The+user+denied+the+authorization+request&state=xYz123
```

---

## Step 3: Process Consent (POST)

The consent form posts to `POST /oauth/authorize`:

```bash
curl -X POST http://auth.zea.localhost/oauth/authorize \
  -H "Content-Type: application/json" \
  -d '{
    "decision": "approve",
    "client_id": "client_xxx",
    "redirect_uri": "https://app.com/callback",
    "scope": "openid profile email",
    "state": "xYz123",
    "code_challenge": "AsdF...",
    "code_challenge_method": "S256"
  }'
```

| Parameter | Required | Description |
|---|---|---|
| `decision` | ✅ | `approve` or `deny` |
| `client_id` | ✅ | OAuth2 client ID |
| `redirect_uri` | ✅ | Must match client's registered URI |
| `scope` | ✅ | Requested scopes |
| `state` | ❌ | Returned in redirect |
| `code_challenge` | ❌ | PKCE challenge |
| `code_challenge_method` | ❌ | `S256` or `plain` |

---

## Step 4: Exchange Code for Tokens (POST)

```bash
curl -X POST http://auth.zea.localhost/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=ac_abc123def456" \
  -d "redirect_uri=https://app.com/callback" \
  -d "client_id=client_xxx" \
  -d "client_secret=secret_xxx" \
  -d "code_verifier=$CODE_VERIFIER"
```

Or with HTTP Basic Auth:

```bash
curl -X POST http://auth.zea.localhost/oauth/token \
  -H "Authorization: Basic $(echo -n 'client_xxx:secret_xxx' | base64)" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=ac_abc123def456" \
  -d "redirect_uri=https://app.com/callback" \
  -d "code_verifier=$CODE_VERIFIER"
```

**Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `grant_type` | ✅ | Must be `authorization_code` |
| `code` | ✅ | Authorization code from Step 2 |
| `redirect_uri` | ✅ | Must match the one used in Step 2 |
| `client_id` | ⚠️ | Required if not using HTTP Basic Auth |
| `client_secret` | ⚠️ | Required if not using HTTP Basic Auth |
| `code_verifier` | ⚠️ | Required if PKCE was used in Step 2 |

### Success Response

```json
{
  "access_token": "at_abc123def456...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "rt_abc123def456...",
  "scope": "openid profile email"
}
```

### Error Responses

```json
// PKCE verification failed
{ "error": "invalid_grant", "error_description": "PKCE verification failed" }

// Client not authenticated
{ "error": "invalid_client", "error_description": "Client authentication failed" }

// Code expired or already used
{ "error": "invalid_grant", "error_description": "The provided authorization grant or refresh token is invalid, expired, or revoked" }

// Wrong redirect_uri
{ "error": "invalid_grant", "error_description": "Invalid redirect URI" }
```

---

## Authorization Code Properties

- **Format**: `ac_` + 32 random chars
- **TTL**: 10 minutes
- **Single-use**: Can only be exchanged once
- **Client-bound**: Tied to the `client_id` that requested it
- **PKCE-bound**: Tied to the `code_challenge` if PKCE was used

---

## See Also

- [OAuth2 Overview](overview.md) — All grants and endpoints
- [Client Credentials](client-credentials.md) — M2M authentication
- [Token Introspection](token-introspection.md) — Validate tokens
- [Token Revocation](token-revocation.md) — Revoke tokens
