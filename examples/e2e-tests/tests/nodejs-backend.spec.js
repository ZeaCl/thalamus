import { test, expect } from '@playwright/test'
import axios from 'axios'

const NODEJS_URL = process.env.NODEJS_URL || 'http://localhost:3000'
const THALAMUS_URL = process.env.THALAMUS_BASE_URL || 'http://localhost:4000'
const CLIENT_ID = process.env.NODEJS_CLIENT_ID
const CLIENT_SECRET = process.env.NODEJS_CLIENT_SECRET

test.describe('Node.js Backend Example @nodejs', () => {
  test('should return health check', async () => {
    const response = await axios.get(`${NODEJS_URL}/api/public/health`)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('status', 'ok')
    expect(response.data).toHaveProperty('message')
  })

  test('should access protected endpoint with M2M auth', async () => {
    const response = await axios.get(`${NODEJS_URL}/api/protected/data`)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('message')
    expect(response.data).toHaveProperty('authenticated', true)
    expect(response.data).toHaveProperty('scopes')
    expect(response.data.scopes).toContain('api:read')
  })

  test('should get service token info', async () => {
    const response = await axios.get(`${NODEJS_URL}/api/token-info`)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('active', true)
    expect(response.data).toHaveProperty('client_id')
    expect(response.data).toHaveProperty('scopes')
    expect(Array.isArray(response.data.scopes)).toBe(true)
  })

  test('should introspect a valid token', async () => {
    // First get a token from Thalamus
    const tokenResponse = await axios.post(
      `${THALAMUS_URL}/oauth/token`,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        scope: 'api:read api:write'
      }),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    )

    const accessToken = tokenResponse.data.access_token

    // Introspect it via Node.js backend
    const response = await axios.post(
      `${NODEJS_URL}/api/introspect`,
      { token: accessToken }
    )

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('active', true)
    expect(response.data).toHaveProperty('client_id', CLIENT_ID)
  })

  test('should cache tokens to avoid excessive requests', async () => {
    const start = Date.now()

    // Make 10 consecutive requests
    const requests = []
    for (let i = 0; i < 10; i++) {
      requests.push(axios.get(`${NODEJS_URL}/api/protected/data`))
    }

    const responses = await Promise.all(requests)
    const duration = Date.now() - start

    // All should succeed
    responses.forEach(response => {
      expect(response.status).toBe(200)
      expect(response.data.authenticated).toBe(true)
    })

    // Should complete quickly due to caching (less than 2 seconds for 10 requests)
    expect(duration).toBeLessThan(2000)
  })

  test('should handle invalid token in introspection', async () => {
    try {
      await axios.post(
        `${NODEJS_URL}/api/introspect`,
        { token: 'invalid_token_12345' }
      )
      // Should not reach here
      expect(true).toBe(false)
    } catch (error) {
      // Should return error
      expect(error.response.status).toBeGreaterThanOrEqual(400)
    }
  })

  test('should handle missing token in introspection request', async () => {
    try {
      await axios.post(`${NODEJS_URL}/api/introspect`, {})
      expect(true).toBe(false) // Should not reach here
    } catch (error) {
      expect(error.response.status).toBe(400)
      expect(error.response.data).toHaveProperty('error')
    }
  })
})
