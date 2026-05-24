import { useEffect, useState } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { thalamus } from '../lib/thalamus'

export default function Callback() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const [error, setError] = useState(null)
  const [processing, setProcessing] = useState(true)

  useEffect(() => {
    async function handleCallback() {
      try {
        const code = searchParams.get('code')
        const state = searchParams.get('state')
        const errorParam = searchParams.get('error')

        // Check for authorization errors
        if (errorParam) {
          const errorDescription = searchParams.get('error_description')
          throw new Error(errorDescription || errorParam)
        }

        // Validate required parameters
        if (!code) {
          throw new Error('No authorization code received')
        }

        // Validate state parameter (CSRF protection)
        const savedState = localStorage.getItem('oauth_state')
        if (!savedState || savedState !== state) {
          throw new Error('Invalid state parameter - possible CSRF attack')
        }

        // Get PKCE code verifier
        const codeVerifier = localStorage.getItem('code_verifier')
        if (!codeVerifier) {
          throw new Error('No code verifier found - PKCE validation will fail')
        }

        // Exchange authorization code for tokens
        const tokens = await thalamus.auth.exchangeCode(code, codeVerifier)

        // Store tokens
        localStorage.setItem('access_token', tokens.access_token)
        if (tokens.refresh_token) {
          localStorage.setItem('refresh_token', tokens.refresh_token)
        }

        // Clean up temporary storage
        localStorage.removeItem('code_verifier')
        localStorage.removeItem('oauth_state')

        // Redirect to dashboard
        navigate('/dashboard', { replace: true })
      } catch (err) {
        console.error('OAuth callback error:', err)
        setError(err.message)
        setProcessing(false)
      }
    }

    handleCallback()
  }, [searchParams, navigate])

  if (error) {
    return (
      <div className="container">
        <div className="card error">
          <h2>Authentication Failed</h2>
          <p>{error}</p>
          <button onClick={() => navigate('/')} className="button">
            Return to Home
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="container">
      <div className="card">
        <h2>Processing authentication...</h2>
        <div className="spinner"></div>
      </div>
    </div>
  )
}
