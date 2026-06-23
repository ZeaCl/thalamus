# Node.js Backend Example with Thalamus

Backend API server demonstrating OAuth2 Client Credentials flow (Machine-to-Machine authentication) using the Thalamus JavaScript SDK.

## Features

- ✅ Express.js REST API
- ✅ Client Credentials flow (M2M authentication)
- ✅ Token caching and auto-refresh
- ✅ Token introspection for validation
- ✅ Protected API endpoints
- ✅ Error handling

## Prerequisites

1. **Running Thalamus server** at `http://localhost:4000`
2. **OAuth2 Client created** in Thalamus dashboard with client credentials enabled

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env`:

```env
THALAMUS_BASE_URL=http://localhost:4000
THALAMUS_CLIENT_ID=your_client_id_here
THALAMUS_CLIENT_SECRET=your_client_secret_here
PORT=3000
```

### 3. Create OAuth2 Client in Thalamus

1. Go to http://localhost:4000/dashboard/clients
2. Click "New Client"
3. Fill in:
   - **Name**: "Node.js Backend Service"
   - **Client Type**: Confidential (with client secret)
   - **Grant Types**: Enable "Client Credentials"
   - **Scopes**: `api:read`, `api:write`
4. Save and copy the `client_id` and `client_secret`
5. Paste them in your `.env` file

## Running

```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

Server runs at http://localhost:3000

## API Endpoints

### Public Endpoints

**GET /api/public/health**
```bash
curl http://localhost:3000/api/public/health
```

Response:
```json
{
  "status": "ok",
  "message": "Server is running"
}
```

### Protected Endpoints (M2M Authentication Required)

**GET /api/protected/data**
```bash
curl http://localhost:3000/api/protected/data
```

Response:
```json
{
  "message": "This is protected data",
  "authenticated": true,
  "scopes": ["api:read", "api:write"],
  "client_id": "your_client_id"
}
```

**POST /api/introspect**
```bash
curl -X POST http://localhost:3000/api/introspect \
  -H "Content-Type: application/json" \
  -d '{"token": "access_token_here"}'
```

**GET /api/token-info**
```bash
curl http://localhost:3000/api/token-info
```

Response:
```json
{
  "active": true,
  "scopes": ["api:read", "api:write"],
  "client_id": "your_client_id",
  "expires_at": "2024-01-22T12:00:00.000Z"
}
```

## How It Works

### 1. Client Credentials Flow

This is a machine-to-machine (M2M) authentication flow where the backend service authenticates itself to Thalamus using its client credentials:

```javascript
// Get access token
const tokens = await thalamus.auth.clientCredentials({
  scope: ['api:read', 'api:write']
})

// Use access token
const accessToken = tokens.access_token
```

### 2. Token Caching

The server caches the access token to avoid requesting a new one on every request:

```javascript
let cachedToken = null
let tokenExpiry = null

// Check if cached token is still valid
if (cachedToken && tokenExpiry && Date.now() < tokenExpiry) {
  return cachedToken
}

// Get new token if expired
const tokens = await thalamus.auth.clientCredentials({ ... })
cachedToken = tokens.access_token
tokenExpiry = Date.now() + (tokens.expires_in - 60) * 1000
```

**Production Note**: Use Redis or another distributed cache instead of in-memory caching for multi-instance deployments.

### 3. Token Validation

Protected endpoints validate tokens using introspection:

```javascript
const validation = await thalamus.tokens.introspect(accessToken)

if (!validation.active) {
  return res.status(401).json({ error: 'Token is not active' })
}
```

### 4. Middleware Pattern

The `ensureToken` middleware ensures a valid access token is available:

```javascript
app.get('/api/protected/data', ensureToken, async (req, res) => {
  // req.accessToken is guaranteed to be valid
  const data = await fetchProtectedData()
  res.json(data)
})
```

## Project Structure

```
nodejs-backend/
├── server.js              # Express server with SDK integration
├── package.json           # Dependencies
├── .env.example           # Environment template
└── README.md              # This file
```

## Security Notes

- ✅ Client secret stored in environment variables (never commit to git)
- ✅ Token caching prevents excessive token requests
- ✅ Token introspection validates tokens on protected endpoints
- ✅ HTTPS required in production
- ⚠️ Use Redis for token caching in production (not in-memory)
- ⚠️ Implement rate limiting for production APIs

## Production Considerations

1. **Token Storage**: Use Redis instead of in-memory cache
2. **HTTPS Only**: Always use HTTPS in production
3. **Error Handling**: Implement comprehensive error handling
4. **Logging**: Add structured logging (Winston, Pino)
5. **Rate Limiting**: Implement rate limiting (express-rate-limit)
6. **Health Checks**: Add health check endpoints for monitoring
7. **Secrets Management**: Use secret management service (AWS Secrets Manager, etc.)

## Testing

Test the client credentials flow:

```bash
# 1. Start server
npm run dev

# 2. Test public endpoint
curl http://localhost:3000/api/public/health

# 3. Test protected endpoint (uses M2M auth automatically)
curl http://localhost:3000/api/protected/data

# 4. Check token info
curl http://localhost:3000/api/token-info
```

## Troubleshooting

**"Failed to authenticate with Thalamus"**
- Check that client_id and client_secret are correct
- Verify that Thalamus server is running
- Ensure client has "Client Credentials" grant enabled

**"Token is not active"**
- Token may have expired
- Check that scopes are correct
- Verify token hasn't been revoked

**"Connection refused"**
- Ensure Thalamus server is running at the configured base URL
- Check firewall settings

## Learn More

- [Thalamus Documentation](../../docs/README.md)
- [OAuth2 Client Credentials Flow](https://oauth.net/2/grant-types/client-credentials/)
- [Thalamus JS SDK](https://github.com/chinostroza/thalamus-js)
- [Express.js Documentation](https://expressjs.com/)
