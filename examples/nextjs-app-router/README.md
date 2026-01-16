# Next.js 14 App Router + Thalamus OAuth2 Example

This is a complete example application demonstrating OAuth2 authentication with ZEA Thalamus using Next.js 14 App Router and the `@zea/thalamus-js` SDK.

## Features

- OAuth2 Authorization Code flow with PKCE
- Server-side token validation
- httpOnly cookies for secure token storage
- CSRF protection with state parameter
- User information display
- Token introspection
- Automatic token revocation on logout

## Prerequisites

- Node.js 18+ installed
- A running Thalamus instance (local or remote)
- OAuth2 client credentials from Thalamus

## Getting Started

### 1. Install Dependencies

```bash
npm install
# or
yarn install
# or
pnpm install
```

### 2. Configure Environment Variables

Copy `.env.example` to `.env.local`:

```bash
cp .env.example .env.local
```

Edit `.env.local` and fill in your values:

```env
THALAMUS_CLIENT_ID=your_client_id_here
THALAMUS_CLIENT_SECRET=your_client_secret_here
THALAMUS_BASE_URL=http://localhost:4000
NEXTAUTH_URL=http://localhost:3000
```

### 3. Configure OAuth2 Client in Thalamus

Make sure your OAuth2 client in Thalamus has the correct redirect URI configured:

- Redirect URI: `http://localhost:3000/auth/callback`

For production, use your production domain:

- Redirect URI: `https://your-app-domain.com/auth/callback`

### 4. Run the Development Server

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Application Flow

1. **Landing Page (`/`)**: Click "Sign In with Thalamus"
2. **Login Route (`/api/auth/login`)**: Redirects to Thalamus authorization page
3. **Thalamus**: User enters credentials and authorizes the application
4. **Callback Route (`/auth/callback`)**: Receives authorization code and exchanges it for tokens
5. **Dashboard (`/dashboard`)**: Displays user information and token details
6. **Logout (`/api/auth/logout`)**: Revokes token and clears cookies

## Project Structure

```
app/
├── page.tsx                      # Landing page
├── dashboard/
│   └── page.tsx                  # Protected dashboard (server component)
├── api/
│   └── auth/
│       ├── login/
│       │   └── route.ts          # OAuth2 login redirect
│       └── logout/
│           └── route.ts          # Token revocation and logout
└── auth/
    └── callback/
        └── route.ts              # OAuth2 callback handler

lib/
└── thalamus.ts                   # Thalamus client configuration
```

## Security Features

### httpOnly Cookies

Tokens are stored in httpOnly cookies to prevent XSS attacks:

```typescript
cookies().set('access_token', tokens.access_token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax',
  path: '/',
  maxAge: tokens.expires_in,
})
```

### CSRF Protection

The OAuth2 state parameter is used for CSRF protection:

```typescript
// Login: Generate and store state
const state = crypto.randomUUID()
cookies().set('oauth_state', state, { httpOnly: true, ... })

// Callback: Validate state
const storedState = cookies().get('oauth_state')?.value
if (storedState !== state) {
  // Reject request
}
```

### Server-Side Validation

All token validation happens on the server:

```typescript
// Dashboard is a Server Component
export default async function Dashboard() {
  const accessToken = cookies().get('access_token')?.value
  const user = await thalamus.tokens.getUserInfo(accessToken)
  // ...
}
```

## Using the Thalamus SDK

This example uses the `@zea/thalamus-js` SDK for all OAuth2 operations:

```typescript
import { ThalamusClient } from '@zea/thalamus-js'

const thalamus = new ThalamusClient({
  clientId: process.env.THALAMUS_CLIENT_ID!,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET!,
  redirectUri: `${process.env.NEXTAUTH_URL}/auth/callback`,
  baseUrl: process.env.THALAMUS_BASE_URL!,
  defaultScopes: ['openid', 'profile', 'email'],
})

// Get authorization URL
const authUrl = thalamus.auth.getAuthorizationUrl({ state })

// Exchange code for tokens
const tokens = await thalamus.auth.exchangeCode(code)

// Get user info
const user = await thalamus.tokens.getUserInfo(accessToken)

// Introspect token
const tokenInfo = await thalamus.tokens.introspect(accessToken)

// Revoke token
await thalamus.auth.revokeToken(accessToken, 'access_token')
```

## Production Deployment

### Environment Variables

Update your production environment variables:

```env
THALAMUS_CLIENT_ID=your_production_client_id
THALAMUS_CLIENT_SECRET=your_production_client_secret
THALAMUS_BASE_URL=https://your-thalamus-domain.com
NEXTAUTH_URL=https://your-app-domain.com
```

### OAuth2 Client Configuration

Update your OAuth2 client redirect URI in Thalamus:

- Redirect URI: `https://your-app-domain.com/auth/callback`

### Security Checklist

- [ ] Use HTTPS in production (cookies with `secure: true`)
- [ ] Store client secret securely (never commit to git)
- [ ] Configure CORS properly in Thalamus
- [ ] Enable rate limiting in Thalamus
- [ ] Monitor authentication logs
- [ ] Implement token refresh logic for long-lived sessions

## Learn More

- [Thalamus Documentation](http://localhost:4000/docs)
- [@zea/thalamus-js SDK](../../packages/thalamus-js/README.md)
- [Next.js App Router Documentation](https://nextjs.org/docs/app)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)

## License

MIT
