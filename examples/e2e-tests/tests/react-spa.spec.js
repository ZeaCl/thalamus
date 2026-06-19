import { test, expect } from '@playwright/test'

const REACT_SPA_URL = process.env.REACT_SPA_URL || 'http://localhost:5173'
const THALAMUS_URL = process.env.THALAMUS_BASE_URL || 'http://localhost:4000'
const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL || 'testuser@example.com'
const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD || 'testpass123'

test.describe('React SPA Example @react-spa', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(REACT_SPA_URL)
  })

  test('should load home page', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Thalamus React SPA Example')
    await expect(page.locator('text=Authorization Code Flow with PKCE')).toBeVisible()
  })

  test('should show login button when not authenticated', async ({ page }) => {
    const loginButton = page.locator('button:has-text("Sign in with Thalamus")')
    await expect(loginButton).toBeVisible()
  })

  test('should complete full OAuth2 login flow', async ({ page, context }) => {
    // Click login button
    const loginButton = page.locator('button:has-text("Sign in with Thalamus")')
    await loginButton.click()

    // Should redirect to Thalamus authorization page
    await page.waitForURL(`${THALAMUS_URL}/oauth/authorize*`)
    await expect(page).toHaveURL(/oauth\/authorize/)

    // Check for PKCE parameters in URL
    const url = page.url()
    expect(url).toContain('code_challenge')
    expect(url).toContain('code_challenge_method=S256')
    expect(url).toContain('response_type=code')

    // Fill login form
    await page.fill('input[name="email"], input[type="email"]', TEST_USER_EMAIL)
    await page.fill('input[name="password"], input[type="password"]', TEST_USER_PASSWORD)

    // Submit login
    await page.click('button[type="submit"]')

    // Wait for redirect to callback
    await page.waitForURL(`${REACT_SPA_URL}/callback*`, { timeout: 10000 })

    // Should process callback and redirect to dashboard
    await page.waitForURL(`${REACT_SPA_URL}/dashboard`, { timeout: 15000 })

    // Verify we're on dashboard
    await expect(page.locator('h1')).toContainText('Dashboard')
    await expect(page.locator('text=Welcome')).toBeVisible()

    // Check that user info is displayed
    await expect(page.locator(`text=${TEST_USER_EMAIL}`)).toBeVisible()

    // Verify token is stored in localStorage
    const accessToken = await page.evaluate(() => localStorage.getItem('access_token'))
    expect(accessToken).toBeTruthy()
    expect(accessToken.length).toBeGreaterThan(20)
  })

  test('should navigate to profile page when authenticated', async ({ page, context }) => {
    // First login (reuse code from previous test or use a helper)
    await loginUser(page)

    // Navigate to profile
    await page.click('a:has-text("View Full Profile")')
    await page.waitForURL(`${REACT_SPA_URL}/profile`)

    // Verify profile page
    await expect(page.locator('h1')).toContainText('User Profile')
    await expect(page.locator('text=Complete User Information')).toBeVisible()

    // Check for JSON preview
    await expect(page.locator('pre.json-preview')).toBeVisible()
  })

  test('should logout successfully', async ({ page }) => {
    // First login
    await loginUser(page)

    // Click logout
    await page.click('button:has-text("Sign out")')

    // Should redirect to home
    await page.waitForURL(REACT_SPA_URL)

    // Verify logged out state
    await expect(page.locator('button:has-text("Sign in with Thalamus")')).toBeVisible()

    // Verify tokens are removed from localStorage
    const accessToken = await page.evaluate(() => localStorage.getItem('access_token'))
    expect(accessToken).toBeNull()
  })

  test('should protect routes when not authenticated', async ({ page }) => {
    // Try to access dashboard directly
    await page.goto(`${REACT_SPA_URL}/dashboard`)

    // Should redirect to home
    await page.waitForURL(REACT_SPA_URL)
    await expect(page.locator('button:has-text("Sign in with Thalamus")')).toBeVisible()
  })

  test('should handle OAuth errors gracefully', async ({ page }) => {
    // Navigate to callback with error parameters
    await page.goto(`${REACT_SPA_URL}/callback?error=access_denied&error_description=User%20denied%20access`)

    // Should show error message
    await expect(page.locator('text=Authentication Failed')).toBeVisible()
    await expect(page.locator('text=User denied access')).toBeVisible()

    // Should have button to return home
    await expect(page.locator('button:has-text("Return to Home")')).toBeVisible()
  })
})

// Helper function to login
async function loginUser(page) {
  const REACT_SPA_URL = process.env.REACT_SPA_URL || 'http://localhost:5173'
  const THALAMUS_URL = process.env.THALAMUS_BASE_URL || 'http://localhost:4000'
  const TEST_USER_EMAIL = process.env.TEST_USER_EMAIL || 'testuser@example.com'
  const TEST_USER_PASSWORD = process.env.TEST_USER_PASSWORD || 'testpass123'

  await page.goto(REACT_SPA_URL)
  await page.click('button:has-text("Sign in with Thalamus")')
  await page.waitForURL(`${THALAMUS_URL}/oauth/authorize*`)
  await page.fill('input[name="email"], input[type="email"]', TEST_USER_EMAIL)
  await page.fill('input[name="password"], input[type="password"]', TEST_USER_PASSWORD)
  await page.click('button[type="submit"]')
  await page.waitForURL(`${REACT_SPA_URL}/dashboard`, { timeout: 15000 })
}
