import 'dotenv/config'
import express from 'express'
import ThalamusClient from '@zea.cl/thalamus-js'

const app = express()
app.use(express.json())

// Initialize Thalamus SDK
const thalamus = new ThalamusClient({
  clientId: process.env.THALAMUS_CLIENT_ID,
  clientSecret: process.env.THALAMUS_CLIENT_SECRET,
  baseUrl: process.env.THALAMUS_BASE_URL
})

// In-memory token cache (use Redis in production)
let cachedToken = null
let tokenExpiry = null

// Middleware to ensure valid access token
async function ensureToken(req, res, next) {
  try {
    // Check if cached token is still valid
    if (cachedToken && tokenExpiry && Date.now() < tokenExpiry) {
      req.accessToken = cachedToken
      return next()
    }

    // Get new token using client credentials
    const tokens = await thalamus.auth.clientCredentials({
      scope: ['api:read', 'api:write']
    })

    // Cache token (subtract 60s for safety margin)
    cachedToken = tokens.access_token
    tokenExpiry = Date.now() + (tokens.expires_in - 60) * 1000

    req.accessToken = cachedToken
    next()
  } catch (error) {
    console.error('Token acquisition failed:', error)
    res.status(500).json({ error: 'Failed to authenticate with Thalamus' })
  }
}

// Public endpoint
app.get('/api/public/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' })
})

// Protected endpoint - requires valid token
app.get('/api/protected/data', ensureToken, async (req, res) => {
  try {
    // Validate token
    const validation = await thalamus.tokens.introspect(req.accessToken)

    if (!validation.active) {
      return res.status(401).json({ error: 'Token is not active' })
    }

    // Return protected data
    res.json({
      message: 'This is protected data',
      authenticated: true,
      scopes: validation.scope,
      client_id: validation.client_id
    })
  } catch (error) {
    console.error('Token validation failed:', error)
    res.status(401).json({ error: 'Token validation failed' })
  }
})

// Introspect a token (for debugging)
app.post('/api/introspect', ensureToken, async (req, res) => {
  try {
    const { token } = req.body

    if (!token) {
      return res.status(400).json({ error: 'Token is required' })
    }

    const result = await thalamus.tokens.introspect(token)
    res.json(result)
  } catch (error) {
    console.error('Introspection failed:', error)
    res.status(500).json({ error: 'Introspection failed' })
  }
})

// Get current service token info
app.get('/api/token-info', ensureToken, async (req, res) => {
  try {
    const info = await thalamus.tokens.introspect(req.accessToken)
    res.json({
      active: info.active,
      scopes: info.scope,
      client_id: info.client_id,
      expires_at: info.exp ? new Date(info.exp * 1000).toISOString() : null
    })
  } catch (error) {
    console.error('Token info failed:', error)
    res.status(500).json({ error: 'Failed to get token info' })
  }
})

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err)
  res.status(500).json({ error: 'Internal server error' })
})

const PORT = process.env.PORT || 3000

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`)
  console.log(`Thalamus server: ${process.env.THALAMUS_BASE_URL}`)
  console.log('\nEndpoints:')
  console.log(`  GET  /api/public/health - Public health check`)
  console.log(`  GET  /api/protected/data - Protected data (requires M2M auth)`)
  console.log(`  POST /api/introspect - Introspect a token`)
  console.log(`  GET  /api/token-info - Get current service token info`)
})
