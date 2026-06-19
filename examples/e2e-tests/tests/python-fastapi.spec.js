import { test, expect } from '@playwright/test'
import axios from 'axios'

const FASTAPI_URL = process.env.FASTAPI_URL || 'http://localhost:8000'
const THALAMUS_URL = process.env.THALAMUS_BASE_URL || 'http://localhost:4000'
const CLIENT_ID = process.env.PYTHON_CLIENT_ID
const CLIENT_SECRET = process.env.PYTHON_CLIENT_SECRET

test.describe('Python FastAPI Example @fastapi', () => {
  test('should return health check from root', async () => {
    const response = await axios.get(FASTAPI_URL)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('status', 'ok')
    expect(response.data).toHaveProperty('message')
  })

  test('should return health check from health endpoint', async () => {
    const response = await axios.get(`${FASTAPI_URL}/api/public/health`)

    expect(response.status).toBe(200)
    expect(response.data.status).toBe('ok')
  })

  test('should have OpenAPI docs available', async () => {
    const response = await axios.get(`${FASTAPI_URL}/docs`)

    expect(response.status).toBe(200)
    expect(response.headers['content-type']).toContain('text/html')
  })

  test('should access protected endpoint with valid Bearer token', async () => {
    // Get a token from Thalamus
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

    // Access protected endpoint
    const response = await axios.get(
      `${FASTAPI_URL}/api/protected/data`,
      {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      }
    )

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('message')
    expect(response.data).toHaveProperty('authenticated', true)
    expect(response.data).toHaveProperty('scopes')
    expect(response.data.scopes).toContain('api:read')
  })

  test('should reject protected endpoint without token', async () => {
    try {
      await axios.get(`${FASTAPI_URL}/api/protected/data`)
      expect(true).toBe(false) // Should not reach here
    } catch (error) {
      expect(error.response.status).toBe(403) // FastAPI HTTPBearer returns 403
    }
  })

  test('should reject protected endpoint with invalid token', async () => {
    try {
      await axios.get(
        `${FASTAPI_URL}/api/protected/data`,
        {
          headers: { 'Authorization': 'Bearer invalid_token_12345' }
        }
      )
      expect(true).toBe(false)
    } catch (error) {
      expect(error.response.status).toBe(401)
    }
  })

  test('should get service token info using M2M', async () => {
    const response = await axios.get(`${FASTAPI_URL}/api/service/token-info`)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('active', true)
    expect(response.data).toHaveProperty('client_id')
    expect(response.data).toHaveProperty('scopes')
    expect(Array.isArray(response.data.scopes)).toBe(true)
  })

  test('should test M2M authentication', async () => {
    const response = await axios.get(`${FASTAPI_URL}/api/service/test-m2m`)

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('message')
    expect(response.data).toHaveProperty('token_active', true)
    expect(response.data).toHaveProperty('client_id', CLIENT_ID)
    expect(response.data).toHaveProperty('scopes')
  })

  test('should introspect token with valid bearer auth', async () => {
    // Get a token
    const tokenResponse = await axios.post(
      `${THALAMUS_URL}/oauth/token`,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        scope: 'api:read'
      }),
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    )

    const accessToken = tokenResponse.data.access_token

    // Introspect it
    const response = await axios.post(
      `${FASTAPI_URL}/api/introspect`,
      { token: accessToken },
      {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      }
    )

    expect(response.status).toBe(200)
    expect(response.data).toHaveProperty('active', true)
    expect(response.data).toHaveProperty('client_id', CLIENT_ID)
  })

  test('should validate response models with Pydantic', async () => {
    const response = await axios.get(`${FASTAPI_URL}/api/public/health`)

    // Check Pydantic model structure
    expect(response.data).toHaveProperty('status')
    expect(response.data).toHaveProperty('message')
    expect(Object.keys(response.data).length).toBe(2) // Only defined fields
  })
})
