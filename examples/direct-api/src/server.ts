/**
 * Direct API Example Server
 *
 * This example demonstrates OAuth2 integration with Thalamus
 * using direct HTTP API calls (no SDK required).
 */

import express, { Request, Response } from 'express'
import cookieParser from 'cookie-parser'
import crypto from 'crypto'
import dotenv from 'dotenv'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 3001

// Configuration
const config = {
  clientId: process.env.THALAMUS_CLIENT_ID!,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET!,
  baseUrl: process.env.THALAMUS_BASE_URL!,
  redirectUri: `${process.env.APP_URL}/auth/callback`,
  scopes: ['openid', 'profile', 'email'],
}

// Middleware
app.use(cookieParser(process.env.SESSION_SECRET))
app.use(express.static('public'))
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Helper function to make API requests
async function thalamusRequest(
  endpoint: string,
  options: RequestInit = {}
): Promise<any> {
  const url = `${config.baseUrl}${endpoint}`

  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Thalamus API error: ${response.status} - ${error}`)
  }

  return response.json()
}

// Routes

// Home page
app.get('/', (req: Request, res: Response) => {
  const accessToken = req.cookies.access_token

  if (accessToken) {
    res.redirect('/dashboard')
    return
  }

  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Direct API Example - Thalamus OAuth2</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            text-align: center;
          }
          .btn {
            display: inline-block;
            padding: 12px 24px;
            background: #3b82f6;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            margin-top: 20px;
          }
          .btn:hover {
            background: #2563eb;
          }
          .note {
            margin-top: 40px;
            padding: 20px;
            background: #f3f4f6;
            border-radius: 8px;
            text-align: left;
          }
          code {
            background: #e5e7eb;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
          }
        </style>
      </head>
      <body>
        <h1>Direct API Example</h1>
        <p>This example demonstrates OAuth2 integration with Thalamus using direct HTTP API calls (no SDK).</p>

        <a href="/auth/login" class="btn">Sign In with Thalamus</a>

        <div class="note">
          <h3>How It Works</h3>
          <ol>
            <li>Click "Sign In" - Redirects to Thalamus authorization page</li>
            <li>Enter credentials - User authenticates with Thalamus</li>
            <li>Authorization callback - Receives code and exchanges for tokens</li>
            <li>Dashboard - Displays user info using access token</li>
          </ol>
          <p><strong>All API calls are made using vanilla <code>fetch()</code></strong></p>
        </div>
      </body>
    </html>
  `)
})

// Login - Redirect to Thalamus authorization page
app.get('/auth/login', (req: Request, res: Response) => {
  // Generate random state for CSRF protection
  const state = crypto.randomUUID()

  // Store state in cookie for validation in callback
  res.cookie('oauth_state', state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 10 * 60 * 1000, // 10 minutes
  })

  // Build authorization URL manually
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    scope: config.scopes.join(' '),
    state,
  })

  const authUrl = `${config.baseUrl}/oauth/authorize?${params.toString()}`

  res.redirect(authUrl)
})

// OAuth2 callback - Exchange code for tokens
app.get('/auth/callback', async (req: Request, res: Response) => {
  const { code, state, error, error_description } = req.query

  // Handle OAuth2 error
  if (error) {
    res.send(`
      <h1>Authentication Error</h1>
      <p>${error_description || error}</p>
      <a href="/">Go back</a>
    `)
    return
  }

  // Validate required parameters
  if (!code || !state) {
    res.status(400).send('Missing required parameters')
    return
  }

  // Verify state (CSRF protection)
  const storedState = req.cookies.oauth_state
  if (!storedState || storedState !== state) {
    res.status(400).send('Invalid state parameter')
    return
  }

  // Clear state cookie
  res.clearCookie('oauth_state')

  try {
    // Exchange authorization code for tokens (direct API call)
    const tokens = await thalamusRequest('/oauth/token', {
      method: 'POST',
      body: JSON.stringify({
        grant_type: 'authorization_code',
        code,
        redirect_uri: config.redirectUri,
        client_id: config.clientId,
        client_secret: config.clientSecret,
      }),
    })

    // Store tokens in httpOnly cookies
    const cookieOptions = {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax' as const,
      path: '/',
    }

    res.cookie('access_token', tokens.access_token, {
      ...cookieOptions,
      maxAge: tokens.expires_in * 1000,
    })

    if (tokens.refresh_token) {
      res.cookie('refresh_token', tokens.refresh_token, {
        ...cookieOptions,
        maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
      })
    }

    // Redirect to dashboard
    res.redirect('/dashboard')
  } catch (error: any) {
    console.error('Token exchange error:', error)
    res.status(500).send(`
      <h1>Token Exchange Error</h1>
      <p>${error.message}</p>
      <a href="/">Go back</a>
    `)
  }
})

// Dashboard - Protected route
app.get('/dashboard', async (req: Request, res: Response) => {
  const accessToken = req.cookies.access_token

  // Redirect to login if not authenticated
  if (!accessToken) {
    res.redirect('/auth/login')
    return
  }

  try {
    // Get user information (direct API call)
    const user = await thalamusRequest('/oauth/userinfo', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    })

    // Get token metadata via introspection (direct API call)
    const tokenInfo = await thalamusRequest('/oauth/introspect', {
      method: 'POST',
      body: JSON.stringify({
        token: accessToken,
        client_id: config.clientId,
        client_secret: config.clientSecret,
      }),
    })

    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Dashboard - Thalamus OAuth2</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              max-width: 1000px;
              margin: 50px auto;
              padding: 20px;
            }
            .header {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 30px;
            }
            .card {
              background: white;
              border: 1px solid #e5e7eb;
              border-radius: 8px;
              padding: 24px;
              margin-bottom: 20px;
              box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            }
            .grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
              gap: 16px;
            }
            .field {
              margin-bottom: 12px;
            }
            .label {
              font-size: 12px;
              color: #6b7280;
              margin-bottom: 4px;
            }
            .value {
              font-family: 'Courier New', monospace;
              font-size: 14px;
              word-break: break-all;
            }
            .btn {
              display: inline-block;
              padding: 10px 20px;
              background: #ef4444;
              color: white;
              text-decoration: none;
              border-radius: 6px;
              font-weight: 600;
            }
            .btn:hover {
              background: #dc2626;
            }
            .badge {
              display: inline-block;
              padding: 4px 8px;
              background: #10b981;
              color: white;
              border-radius: 4px;
              font-size: 12px;
              font-weight: 600;
            }
            pre {
              background: #f3f4f6;
              padding: 16px;
              border-radius: 6px;
              overflow-x: auto;
            }
            details {
              margin-top: 20px;
            }
            summary {
              cursor: pointer;
              color: #3b82f6;
              font-weight: 600;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>Dashboard</h1>
            <a href="/auth/logout" class="btn">Logout</a>
          </div>

          <div class="card">
            <h2>User Information</h2>
            <div class="grid">
              <div class="field">
                <div class="label">User ID</div>
                <div class="value">${user.sub}</div>
              </div>
              <div class="field">
                <div class="label">Email</div>
                <div class="value">${user.email}</div>
              </div>
              <div class="field">
                <div class="label">Name</div>
                <div class="value">${user.name || 'N/A'}</div>
              </div>
              <div class="field">
                <div class="label">Email Verified</div>
                <div class="value">${user.email_verified ? '✅ Yes' : '❌ No'}</div>
              </div>
              ${user.organization_id ? `
                <div class="field">
                  <div class="label">Organization ID</div>
                  <div class="value">${user.organization_id}</div>
                </div>
              ` : ''}
            </div>
          </div>

          <div class="card">
            <h2>Token Information</h2>
            <div class="grid">
              <div class="field">
                <div class="label">Token Status</div>
                <div class="value">
                  ${tokenInfo.active ? '<span class="badge">Active</span>' : '<span class="badge" style="background: #ef4444">Inactive</span>'}
                </div>
              </div>
              <div class="field">
                <div class="label">Client ID</div>
                <div class="value">${tokenInfo.client_id}</div>
              </div>
              <div class="field">
                <div class="label">Scopes</div>
                <div class="value">${tokenInfo.scope}</div>
              </div>
              <div class="field">
                <div class="label">Expires At</div>
                <div class="value">${new Date(tokenInfo.exp * 1000).toLocaleString()}</div>
              </div>
              <div class="field">
                <div class="label">Issued At</div>
                <div class="value">${new Date(tokenInfo.iat * 1000).toLocaleString()}</div>
              </div>
            </div>
          </div>

          <details>
            <summary>Show Raw JSON</summary>
            <div style="margin-top: 16px">
              <h3>User Info:</h3>
              <pre>${JSON.stringify(user, null, 2)}</pre>
              <h3>Token Info:</h3>
              <pre>${JSON.stringify(tokenInfo, null, 2)}</pre>
            </div>
          </details>
        </body>
      </html>
    `)
  } catch (error: any) {
    console.error('Error fetching user data:', error)
    res.status(500).send(`
      <h1>Error</h1>
      <p>${error.message}</p>
      <a href="/auth/logout">Logout and try again</a>
    `)
  }
})

// Logout - Revoke token and clear cookies
app.get('/auth/logout', async (req: Request, res: Response) => {
  const accessToken = req.cookies.access_token

  // Revoke token with Thalamus (direct API call)
  if (accessToken) {
    try {
      await thalamusRequest('/oauth/revoke', {
        method: 'POST',
        body: JSON.stringify({
          token: accessToken,
          token_type_hint: 'access_token',
          client_id: config.clientId,
          client_secret: config.clientSecret,
        }),
      })
    } catch (error) {
      // Log but don't fail logout if revocation fails
      console.error('Token revocation error:', error)
    }
  }

  // Clear authentication cookies
  res.clearCookie('access_token')
  res.clearCookie('refresh_token')

  // Redirect to home page
  res.redirect('/')
})

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 Direct API Example Server running on http://localhost:${PORT}`)
  console.log(`\n📝 Make sure to:`)
  console.log(`   1. Copy .env.example to .env and fill in your values`)
  console.log(`   2. Configure redirect URI in Thalamus: ${config.redirectUri}`)
  console.log(`   3. Ensure Thalamus is running on ${config.baseUrl}\n`)
})
