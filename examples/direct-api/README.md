# Direct API Example - Thalamus OAuth2

This example demonstrates OAuth2 integration with ZEA Thalamus using **direct HTTP API calls** without any SDK. It shows developers exactly how the OAuth2 flow works under the hood using vanilla `fetch()` calls.

## Why This Example?

- **Understand OAuth2**: See the exact HTTP requests and responses
- **Language Agnostic**: Adapt this pattern to any programming language
- **No Dependencies**: Only uses standard HTTP client (fetch)
- **Full Control**: Customize every aspect of the integration

## Features

- OAuth2 Authorization Code flow with PKCE
- Direct API calls using `fetch()`
- CSRF protection with state parameter
- httpOnly cookies for token storage
- Token introspection
- Token revocation on logout
- Simple Express.js server with TypeScript

## Prerequisites

- Node.js 18+ installed
- A running Thalamus instance (local or remote)
- OAuth2 client credentials from Thalamus

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

```env
THALAMUS_CLIENT_ID=your_client_id_here
THALAMUS_CLIENT_SECRET=your_client_secret_here
THALAMUS_BASE_URL=http://localhost:4000
APP_URL=http://localhost:3001
PORT=3001
SESSION_SECRET=your_random_secret_here
```

### 3. Configure OAuth2 Client in Thalamus

Make sure your OAuth2 client in Thalamus has the correct redirect URI:

- Redirect URI: `http://localhost:3001/auth/callback`

### 4. Run the Server

```bash
npm run dev
```

Open [http://localhost:3001](http://localhost:3001) in your browser.

## OAuth2 Flow Explained

### Step 1: Authorization Request

When user clicks "Sign In", the app redirects to Thalamus:

```typescript
const params = new URLSearchParams({
  response_type: 'code',
  client_id: config.clientId,
  redirect_uri: config.redirectUri,
  scope: 'openid profile email',
  state: '<random_state>',
})

const authUrl = `${config.baseUrl}/oauth/authorize?${params}`
// Redirect user to authUrl
```

**Request:**
```
GET /oauth/authorize?response_type=code&client_id=xxx&redirect_uri=xxx&scope=openid+profile+email&state=xxx
Host: localhost:4000
```

### Step 2: User Authentication

User enters credentials on Thalamus and authorizes the application.

### Step 3: Authorization Callback

Thalamus redirects back with an authorization code:

```
GET /auth/callback?code=xxx&state=xxx
Host: localhost:3001
```

### Step 4: Token Exchange

Exchange authorization code for access token:

```typescript
const response = await fetch(`${config.baseUrl}/oauth/token`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    grant_type: 'authorization_code',
    code: code,
    redirect_uri: config.redirectUri,
    client_id: config.clientId,
    client_secret: config.clientSecret,
  }),
})

const tokens = await response.json()
```

**Request:**
```http
POST /oauth/token HTTP/1.1
Host: localhost:4000
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "xxx",
  "redirect_uri": "http://localhost:3001/auth/callback",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "xxx",
  "scope": "openid profile email"
}
```

### Step 5: Get User Information

Use access token to fetch user data:

```typescript
const response = await fetch(`${config.baseUrl}/oauth/userinfo`, {
  headers: {
    'Authorization': `Bearer ${accessToken}`,
  },
})

const user = await response.json()
```

**Request:**
```http
GET /oauth/userinfo HTTP/1.1
Host: localhost:4000
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
  "sub": "user_123",
  "email": "user@example.com",
  "email_verified": true,
  "name": "John Doe",
  "organization_id": "org_456"
}
```

### Step 6: Introspect Token

Validate and get metadata about a token:

```typescript
const response = await fetch(`${config.baseUrl}/oauth/introspect`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    token: accessToken,
    client_id: config.clientId,
    client_secret: config.clientSecret,
  }),
})

const tokenInfo = await response.json()
```

**Request:**
```http
POST /oauth/introspect HTTP/1.1
Host: localhost:4000
Content-Type: application/json

{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

**Response:**
```json
{
  "active": true,
  "scope": "openid profile email",
  "client_id": "your_client_id",
  "user_id": "user_123",
  "exp": 1704067200,
  "iat": 1704063600,
  "token_type": "Bearer"
}
```

### Step 7: Revoke Token (Logout)

Revoke the access token:

```typescript
const response = await fetch(`${config.baseUrl}/oauth/revoke`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    token: accessToken,
    token_type_hint: 'access_token',
    client_id: config.clientId,
    client_secret: config.clientSecret,
  }),
})
```

**Request:**
```http
POST /oauth/revoke HTTP/1.1
Host: localhost:4000
Content-Type: application/json

{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type_hint": "access_token",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

**Response:**
```http
HTTP/1.1 200 OK
```

## API Endpoints Reference

### Authorization Endpoint

```
GET /oauth/authorize
```

**Query Parameters:**
- `response_type` (required): `code`
- `client_id` (required): Your client ID
- `redirect_uri` (required): Callback URL
- `scope` (required): Space-separated scopes
- `state` (required): Random string for CSRF protection

### Token Endpoint

```
POST /oauth/token
```

**Body (Authorization Code Grant):**
```json
{
  "grant_type": "authorization_code",
  "code": "authorization_code",
  "redirect_uri": "callback_url",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

**Body (Refresh Token Grant):**
```json
{
  "grant_type": "refresh_token",
  "refresh_token": "refresh_token",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

**Body (Client Credentials Grant):**
```json
{
  "grant_type": "client_credentials",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret",
  "scope": "optional_scopes"
}
```

### UserInfo Endpoint

```
GET /oauth/userinfo
Authorization: Bearer <access_token>
```

### Introspection Endpoint

```
POST /oauth/introspect
```

**Body:**
```json
{
  "token": "access_token",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

### Revocation Endpoint

```
POST /oauth/revoke
```

**Body:**
```json
{
  "token": "access_token_or_refresh_token",
  "token_type_hint": "access_token",
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```

## Security Best Practices

### 1. Always Use HTTPS in Production

```typescript
const cookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production', // HTTPS only in production
  sameSite: 'lax',
}
```

### 2. Validate State Parameter

```typescript
// Store state before redirect
const state = crypto.randomUUID()
res.cookie('oauth_state', state, { httpOnly: true })

// Validate in callback
const storedState = req.cookies.oauth_state
if (storedState !== state) {
  throw new Error('Invalid state - possible CSRF attack')
}
```

### 3. Use httpOnly Cookies

```typescript
// Never expose tokens to JavaScript
res.cookie('access_token', token, {
  httpOnly: true,  // Prevents XSS attacks
  secure: true,
  sameSite: 'lax',
})
```

### 4. Never Expose Client Secret in Frontend

Client secret should ONLY be used in backend/server-side code.

### 5. Implement Token Refresh

```typescript
async function refreshAccessToken(refreshToken: string) {
  const response = await fetch(`${config.baseUrl}/oauth/token`, {
    method: 'POST',
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: config.clientId,
      client_secret: config.clientSecret,
    }),
  })

  return response.json()
}
```

## Adapting to Other Languages

This pattern works in any language with an HTTP client:

### Python (using `requests`)

```python
import requests

# Token exchange
response = requests.post(
    f"{base_url}/oauth/token",
    json={
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "client_secret": client_secret,
    }
)
tokens = response.json()
```

### Go (using `net/http`)

```go
data := map[string]string{
    "grant_type":    "authorization_code",
    "code":          code,
    "redirect_uri":  redirectUri,
    "client_id":     clientId,
    "client_secret": clientSecret,
}

jsonData, _ := json.Marshal(data)
resp, _ := http.Post(
    baseUrl+"/oauth/token",
    "application/json",
    bytes.NewBuffer(jsonData),
)
```

### PHP (using `cURL`)

```php
$data = [
    'grant_type' => 'authorization_code',
    'code' => $code,
    'redirect_uri' => $redirectUri,
    'client_id' => $clientId,
    'client_secret' => $clientSecret,
];

$ch = curl_init($baseUrl . '/oauth/token');
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
$response = curl_exec($ch);
```

## Troubleshooting

### "Invalid client" error

- Verify `client_id` and `client_secret` are correct
- Check that client exists in Thalamus database

### "Invalid redirect_uri" error

- Ensure redirect URI matches exactly what's configured in Thalamus
- Include protocol (http/https) and port number

### "Invalid state" error

- State parameter mismatch (possible CSRF attack)
- Check cookie configuration (httpOnly, sameSite)
- Verify state is stored before redirect

### Token expired

- Implement token refresh logic
- Check token expiration time (`exp` claim)

## Learn More

- [Thalamus Documentation](http://localhost:4000/docs)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.0 Token Introspection RFC 7662](https://tools.ietf.org/html/rfc7662)
- [OAuth 2.0 Token Revocation RFC 7009](https://tools.ietf.org/html/rfc7009)

## License

MIT
