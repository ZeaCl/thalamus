# React SPA Example with Thalamus

Single Page Application demonstrating OAuth2 Authorization Code Flow with PKCE using the Thalamus JavaScript SDK.

## Features

- ✅ React 18 + Vite
- ✅ Authorization Code Flow with PKCE
- ✅ Token management and auto-refresh
- ✅ Protected routes
- ✅ User profile display
- ✅ Logout functionality

## Prerequisites

1. **Running Thalamus server** at `http://localhost:4000`
2. **OAuth2 Client created** in Thalamus dashboard

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
VITE_THALAMUS_BASE_URL=http://localhost:4000
VITE_THALAMUS_CLIENT_ID=your_client_id_here
VITE_REDIRECT_URI=http://localhost:5173/callback
```

### 3. Create OAuth2 Client in Thalamus

1. Go to http://localhost:4000/dashboard/clients
2. Click "New Client"
3. Fill in:
   - **Name**: "React SPA Example"
   - **Client Type**: Public (no client secret for SPA)
   - **Redirect URIs**: `http://localhost:5173/callback`
   - **Scopes**: `openid`, `profile`, `email`, `api:read`
4. Save and copy the `client_id`
5. Paste it in your `.env` file

## Running

```bash
npm run dev
```

Open http://localhost:5173

## How It Works

### 1. Authorization Flow

When user clicks "Login":
1. App redirects to Thalamus `/oauth/authorize`
2. User logs in at Thalamus
3. Thalamus redirects back to `/callback` with authorization code
4. App exchanges code for access token using PKCE
5. Token is stored in localStorage
6. User is redirected to dashboard

### 2. PKCE (Proof Key for Code Exchange)

Since this is a public client (SPA), we use PKCE for security:

```javascript
// Generate code verifier and challenge
const codeVerifier = generateRandomString(128)
const codeChallenge = await sha256(codeVerifier)

// Store verifier for later
localStorage.setItem('code_verifier', codeVerifier)

// Send challenge in authorization request
const authUrl = `${baseUrl}/oauth/authorize?
  response_type=code&
  client_id=${clientId}&
  redirect_uri=${redirectUri}&
  code_challenge=${codeChallenge}&
  code_challenge_method=S256&
  scope=${scopes}`
```

### 3. Token Management

The SDK handles:
- Token storage
- Auto-refresh before expiration
- Token validation
- Logout (token revocation)

### 4. Protected Routes

```javascript
function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth()

  if (!isAuthenticated) {
    return <Navigate to="/login" />
  }

  return children
}
```

## Project Structure

```
react-spa/
├── src/
│   ├── components/
│   │   ├── LoginButton.jsx      # Login button component
│   │   ├── LogoutButton.jsx     # Logout button component
│   │   └── ProtectedRoute.jsx   # Route protection
│   ├── lib/
│   │   └── thalamus.js          # Thalamus SDK configuration
│   ├── pages/
│   │   ├── Home.jsx             # Landing page
│   │   ├── Callback.jsx         # OAuth callback handler
│   │   ├── Dashboard.jsx        # Protected dashboard
│   │   └── Profile.jsx          # User profile
│   ├── App.jsx                  # Main app component
│   └── main.jsx                 # Entry point
├── .env.example                 # Environment template
├── package.json
└── README.md
```

## Key Code Snippets

### Initialize SDK

```javascript
// src/lib/thalamus.js
import ThalamusClient from '@zea.cl/thalamus-js'

export const thalamus = new ThalamusClient({
  clientId: import.meta.env.VITE_THALAMUS_CLIENT_ID,
  redirectUri: import.meta.env.VITE_REDIRECT_URI,
  baseUrl: import.meta.env.VITE_THALAMUS_BASE_URL,
  defaultScopes: ['openid', 'profile', 'email', 'api:read']
})
```

### Login

```javascript
// src/components/LoginButton.jsx
function handleLogin() {
  const authUrl = thalamus.auth.getAuthorizationUrl({
    scope: ['openid', 'profile', 'email'],
    state: generateRandomState()
  })

  window.location.href = authUrl
}
```

### Handle Callback

```javascript
// src/pages/Callback.jsx
const { code } = useSearchParams()

useEffect(() => {
  async function exchangeCode() {
    const tokens = await thalamus.auth.exchangeCode(code)
    localStorage.setItem('access_token', tokens.access_token)
    localStorage.setItem('refresh_token', tokens.refresh_token)
    navigate('/dashboard')
  }

  exchangeCode()
}, [code])
```

### Get User Info

```javascript
// src/pages/Dashboard.jsx
const token = localStorage.getItem('access_token')
const user = await thalamus.tokens.getUserInfo(token)

console.log(user.email)
console.log(user.name)
```

## Security Notes

- ✅ Uses PKCE (no client secret exposed)
- ✅ State parameter for CSRF protection
- ✅ Tokens stored in localStorage (consider httpOnly cookies for production)
- ✅ Token validation on each protected route
- ✅ Auto-refresh prevents token expiration

## Production Considerations

1. **Token Storage**: Use httpOnly cookies instead of localStorage
2. **HTTPS Only**: Always use HTTPS in production
3. **State Validation**: Verify state parameter in callback
4. **Error Handling**: Add proper error boundaries
5. **Loading States**: Show loading indicators during auth
6. **Token Refresh**: Implement auto-refresh before expiration

## Troubleshooting

**"Invalid redirect_uri"**
- Make sure redirect URI in `.env` matches exactly what's configured in Thalamus client

**"PKCE validation failed"**
- Check that code_verifier is properly stored and retrieved

**"Token expired"**
- Implement token refresh or redirect to login

## Learn More

- [Thalamus Documentation](../../docs/README.md)
- [OAuth2 Authorization Code Flow](https://oauth.net/2/grant-types/authorization-code/)
- [PKCE RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [Thalamus JS SDK](https://github.com/chinostroza/thalamus-js)
