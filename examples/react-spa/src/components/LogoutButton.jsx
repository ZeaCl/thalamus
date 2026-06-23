import { useNavigate } from 'react-router-dom'
import { thalamus } from '../lib/thalamus'

export default function LogoutButton() {
  const navigate = useNavigate()

  async function handleLogout() {
    try {
      const accessToken = localStorage.getItem('access_token')

      if (accessToken) {
        // Revoke token on server
        await thalamus.tokens.revoke(accessToken)
      }
    } catch (error) {
      console.error('Logout error:', error)
    } finally {
      // Clear local storage regardless of revocation success
      localStorage.removeItem('access_token')
      localStorage.removeItem('refresh_token')
      localStorage.removeItem('code_verifier')
      localStorage.removeItem('oauth_state')

      // Redirect to home
      navigate('/')
    }
  }

  return (
    <button onClick={handleLogout} className="logout-button">
      Sign out
    </button>
  )
}
