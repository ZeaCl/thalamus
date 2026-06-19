import { thalamus, generateRandomString, sha256 } from '../lib/thalamus'

export default function LoginButton() {
  async function handleLogin() {
    try {
      // Generate PKCE parameters
      const codeVerifier = generateRandomString(128)
      const codeChallenge = await sha256(codeVerifier)
      const state = generateRandomString(32)

      // Store for later use in callback
      localStorage.setItem('code_verifier', codeVerifier)
      localStorage.setItem('oauth_state', state)

      // Build authorization URL
      const authUrl = thalamus.auth.getAuthorizationUrl({
        scope: ['openid', 'profile', 'email', 'api:read'],
        state,
        codeChallenge,
        codeChallengeMethod: 'S256'
      })

      // Redirect to Thalamus authorization page
      window.location.href = authUrl
    } catch (error) {
      console.error('Login error:', error)
      alert('Failed to initiate login')
    }
  }

  return (
    <button
      onClick={handleLogin}
      className="login-button"
    >
      Sign in with Thalamus
    </button>
  )
}
