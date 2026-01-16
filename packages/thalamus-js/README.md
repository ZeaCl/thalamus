# @zea/thalamus-js

Official JavaScript/TypeScript SDK for ZEA Thalamus OAuth2 Server.

[![npm version](https://img.shields.io/npm/v/@zea/thalamus-js.svg)](https://www.npmjs.com/package/@zea/thalamus-js)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **OAuth2 2.0 compliant** - Authorization Code, Client Credentials, Refresh Token flows
- ✅ **TypeScript support** - Full type definitions included
- ✅ **Zero dependencies** - Lightweight and secure
- ✅ **Modern & Simple API** - Easy to use, hard to misuse
- ✅ **Node.js & Browser** - Works everywhere JavaScript runs
- ✅ **Token Management** - Built-in introspection and validation
- ✅ **PKCE support** - Enhanced security for public clients

## Installation

```bash
npm install @zea/thalamus-js
# or
yarn add @zea/thalamus-js
# or
pnpm add @zea/thalamus-js
```

## Quick Start

```typescript
import ThalamusClient from '@zea/thalamus-js'

// Initialize the client
const thalamus = new ThalamusClient({
  clientId: process.env.THALAMUS_CLIENT_ID!,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET, // Optional for public clients
  redirectUri: 'https://yourapp.com/auth/callback',
  baseUrl: 'https://auth.example.com'
})

// 1. Get authorization URL
const authUrl = thalamus.auth.getAuthorizationUrl({
  scope: ['openid', 'profile', 'email'],
  state: 'random-state-string'
})

// Redirect user to authUrl...

// 2. Exchange authorization code for tokens
const tokens = await thalamus.auth.exchangeCode('authorization_code_from_callback')

console.log(tokens.access_token)
console.log(tokens.refresh_token)
console.log(tokens.expires_in)

// 3. Introspect token
const tokenInfo = await thalamus.tokens.introspect(tokens.access_token)

if (tokenInfo.active) {
  console.log('User ID:', tokenInfo.user_id)
  console.log('Email:', tokenInfo.email)
  console.log('Scopes:', tokenInfo.scope)
}
```

## Usage Examples

### Authorization Code Flow (Web Apps)

The most common flow for web applications with user login:

```typescript
import ThalamusClient from '@zea/thalamus-js'

const thalamus = new ThalamusClient({
  clientId: 'your_client_id',
  clientSecret: 'your_client_secret',
  redirectUri: 'https://yourapp.com/auth/callback',
  baseUrl: 'https://auth.example.com'
})

// Step 1: Redirect user to login
app.get('/login', (req, res) => {
  const authUrl = thalamus.auth.getAuthorizationUrl({
    scope: ['openid', 'profile', 'email'],
    state: generateRandomState() // Implement CSRF protection
  })

  res.redirect(authUrl)
})

// Step 2: Handle callback
app.get('/auth/callback', async (req, res) => {
  const { code, state } = req.query

  // Verify state parameter (CSRF protection)
  if (state !== req.session.oauthState) {
    return res.status(400).send('Invalid state')
  }

  // Exchange code for tokens
  const tokens = await thalamus.auth.exchangeCode(code)

  // Store tokens securely (e.g., httpOnly cookies, session)
  req.session.accessToken = tokens.access_token
  req.session.refreshToken = tokens.refresh_token

  res.redirect('/dashboard')
})
```

### Client Credentials Flow (M2M)

For backend services and machine-to-machine authentication:

```typescript
const thalamus = new ThalamusClient({
  clientId: 'your_client_id',
  clientSecret: 'your_client_secret',
  redirectUri: 'https://yourapp.com/callback', // Not used in this flow
  baseUrl: 'https://auth.example.com'
})

// Get machine-to-machine token
const tokens = await thalamus.auth.getClientCredentialsToken({
  scope: ['api:read', 'api:write']
})

// Use the access token for API calls
const response = await fetch('https://api.example.com/data', {
  headers: {
    'Authorization': `Bearer ${tokens.access_token}`
  }
})
```

### Refresh Token

Renew expired access tokens without requiring user login:

```typescript
const newTokens = await thalamus.auth.refreshToken({
  refreshToken: 'rt_...'
})

console.log(newTokens.access_token)
console.log(newTokens.refresh_token) // New refresh token (token rotation)
```

### Token Introspection

Validate tokens and retrieve metadata:

```typescript
const tokenInfo = await thalamus.tokens.introspect(accessToken)

if (tokenInfo.active) {
  console.log('Token is valid')
  console.log('User ID:', tokenInfo.user_id)
  console.log('Email:', tokenInfo.email)
  console.log('Organization:', tokenInfo.organization_id)
  console.log('Scopes:', tokenInfo.scope)
  console.log('Expires at:', new Date(tokenInfo.exp! * 1000))
} else {
  console.log('Token is invalid or expired')
}
```

### Get User Info (OpenID Connect)

Retrieve user profile information:

```typescript
const user = await thalamus.tokens.getUserInfo(accessToken)

console.log('User ID:', user.sub)
console.log('Email:', user.email)
console.log('Name:', user.name)
console.log('Email Verified:', user.email_verified)
console.log('Organization:', user.organization_id)
```

### Revoke Token

Revoke an access or refresh token:

```typescript
await thalamus.auth.revokeToken(accessToken, 'access_token')
```

### Simple Token Validation

Quick helper to check if a token is valid:

```typescript
const isValid = await thalamus.tokens.validate(accessToken)

if (isValid) {
  // Proceed with authenticated request
} else {
  // Token is invalid, redirect to login
}
```

## API Reference

### `ThalamusClient`

Main client class.

#### Constructor

```typescript
new ThalamusClient(config: ThalamusConfig)
```

**Config Options:**

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `clientId` | `string` | Yes | OAuth2 client ID |
| `clientSecret` | `string` | No* | OAuth2 client secret (*required for confidential clients) |
| `redirectUri` | `string` | Yes | Callback URL for authorization |
| `baseUrl` | `string` | Yes | Thalamus server base URL |
| `defaultScopes` | `string[]` | No | Default scopes to request (default: `['openid', 'profile', 'email']`) |

### `thalamus.auth` (OAuth2)

OAuth2 authentication methods.

#### `getAuthorizationUrl(options?)`

Generate authorization URL for user login.

**Options:**
- `scope`: `string[]` - Scopes to request
- `state`: `string` - CSRF protection state
- `responseType`: `'code'` - Response type (default: 'code')

**Returns:** `string` - Authorization URL

#### `exchangeCode(code)`

Exchange authorization code for access token.

**Parameters:**
- `code`: `string` - Authorization code from callback

**Returns:** `Promise<TokenResponse>`

#### `getClientCredentialsToken(options?)`

Get access token using client credentials (M2M).

**Options:**
- `scope`: `string[]` - Scopes to request

**Returns:** `Promise<TokenResponse>`

#### `refreshToken(options)`

Refresh access token.

**Options:**
- `refreshToken`: `string` - Refresh token

**Returns:** `Promise<TokenResponse>`

#### `revokeToken(token, tokenTypeHint?)`

Revoke a token.

**Parameters:**
- `token`: `string` - Token to revoke
- `tokenTypeHint`: `'access_token' | 'refresh_token'` - Type hint (optional)

**Returns:** `Promise<void>`

### `thalamus.tokens` (TokenManager)

Token management and introspection.

#### `introspect(token)`

Introspect a token to check validity and get metadata.

**Parameters:**
- `token`: `string` - Access token

**Returns:** `Promise<IntrospectionResponse>`

#### `getUserInfo(accessToken)`

Get user information from OpenID Connect userinfo endpoint.

**Parameters:**
- `accessToken`: `string` - Access token

**Returns:** `Promise<UserInfo>`

#### `validate(token)`

Simple boolean check if token is valid.

**Parameters:**
- `token`: `string` - Access token

**Returns:** `Promise<boolean>`

## TypeScript Support

This SDK is written in TypeScript and includes full type definitions:

```typescript
import ThalamusClient, {
  type TokenResponse,
  type IntrospectionResponse,
  type UserInfo
} from '@zea/thalamus-js'

const tokens: TokenResponse = await thalamus.auth.exchangeCode(code)
const tokenInfo: IntrospectionResponse = await thalamus.tokens.introspect(token)
const user: UserInfo = await thalamus.tokens.getUserInfo(token)
```

## Error Handling

All methods throw `ThalamusError` on failure:

```typescript
import ThalamusClient, { type ThalamusError } from '@zea/thalamus-js'

try {
  const tokens = await thalamus.auth.exchangeCode(code)
} catch (error) {
  const thalamusError = error as ThalamusError
  console.error('Status:', thalamusError.statusCode)
  console.error('Error:', thalamusError.error)
  console.error('Description:', thalamusError.error_description)
}
```

## Examples

Check out complete working examples:

- **Next.js 14 App Router** - `examples/nextjs-app-router/`
- **Express.js API** - `examples/express-api/`
- **Direct API Calls** - `examples/direct-api/`

## Security Best Practices

1. **Never expose client secret** in client-side code
2. **Use httpOnly cookies** for storing tokens in web apps
3. **Always validate state parameter** to prevent CSRF attacks
4. **Use HTTPS only** in production
5. **Implement token refresh** before expiration
6. **Revoke tokens** on logout

## Support

- 📖 [Full Documentation](https://your-thalamus.com/docs)
- 💬 [GitHub Issues](https://github.com/zea/thalamus/issues)
- 📧 [Email Support](mailto:support@zea.com)

## License

MIT © ZEA

---

Built with ❤️ by the ZEA team
