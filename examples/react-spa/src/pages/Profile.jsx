import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { thalamus } from '../lib/thalamus'
import LogoutButton from '../components/LogoutButton'

export default function Profile() {
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
          <h2>Loading profile...</h2>
          <div className="spinner"></div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="container">
        <div className="card error">
          <h2>Error Loading Profile</h2>
          <p>{error}</p>
          <Link to="/dashboard" className="button">Back to Dashboard</Link>
        </div>
      </div>
    )
  }

  return (
    <div className="container">
      <div className="header">
        <h1>User Profile</h1>
        <div className="header-actions">
          <Link to="/dashboard" className="button-secondary">Back to Dashboard</Link>
          <LogoutButton />
        </div>
      </div>

      <div className="card">
        <h2>Complete User Information</h2>

        <div className="profile-grid">
          {Object.entries(user || {}).map(([key, value]) => (
            <div key={key} className="profile-item">
              <strong>{key}:</strong>
              <span>{typeof value === 'object' ? JSON.stringify(value) : value}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="card">
        <h3>Raw JSON Response</h3>
        <pre className="json-preview">
          {JSON.stringify(user, null, 2)}
        </pre>
      </div>
    </div>
  )
}
