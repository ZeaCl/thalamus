import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { thalamus } from '../lib/thalamus'
import LogoutButton from '../components/LogoutButton'

export default function Dashboard() {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchUserInfo() {
      try {
        const accessToken = localStorage.getItem('access_token')

        if (!accessToken) {
          throw new Error('No access token found')
        }

        // Get user info from Thalamus
        const userInfo = await thalamus.tokens.getUserInfo(accessToken)
        setUser(userInfo)
      } catch (err) {
        console.error('Failed to fetch user info:', err)
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }

    fetchUserInfo()
  }, [])

  if (loading) {
    return (
      <div className="container">
        <div className="card">
          <h2>Loading...</h2>
          <div className="spinner"></div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container">
        <div className="card error">
          <h2>Error Loading User Info</h2>
          <p>{error}</p>
          <LogoutButton />
        </div>
      </div>
    )
  }

  return (
    <div className="container">
      <div className="header">
        <h1>Dashboard</h1>
        <LogoutButton />
      </div>

      <div className="card">
        <h2>Welcome, {user?.name || user?.email || 'User'}!</h2>

        <div className="user-info">
          <div className="info-item">
            <strong>Email:</strong> {user?.email || 'N/A'}
          </div>
          {user?.name && (
            <div className="info-item">
              <strong>Name:</strong> {user.name}
            </div>
          )}
          {user?.sub && (
            <div className="info-item">
              <strong>User ID:</strong> {user.sub}
            </div>
          )}
        </div>

        <div className="actions">
          <Link to="/profile" className="button">
            View Full Profile
          </Link>
        </div>
      </div>

      <div className="card">
        <h3>Token Information</h3>
        <div className="info-item">
          <strong>Access Token:</strong>{' '}
          <code className="token-preview">
            {localStorage.getItem('access_token')?.substring(0, 20)}...
          </code>
        </div>
        {localStorage.getItem('refresh_token') && (
          <div className="info-item">
            <strong>Refresh Token:</strong> Available
          </div>
        )}
      </div>
    </div>
  )
}
