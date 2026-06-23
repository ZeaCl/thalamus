import { Link } from 'react-router-dom'
import LoginButton from '../components/LoginButton'

export default function Home() {
  const isAuthenticated = !!localStorage.getItem('access_token')

  return (
    <div className="container">
      <h1>Thalamus React SPA Example</h1>

      <div className="card">
        <h2>OAuth2 Authorization Code Flow with PKCE</h2>
        <p>
          This example demonstrates how to integrate Thalamus OAuth2 authentication
          in a React Single Page Application using the official{' '}
          <code>@zea.cl/thalamus-js</code> SDK.
        </p>

        <h3>Features:</h3>
        <ul>
          <li>✅ Authorization Code Flow with PKCE</li>
          <li>✅ Token management and auto-refresh</li>
          <li>✅ Protected routes</li>
          <li>✅ User profile display</li>
          <li>✅ Secure token storage</li>
        </ul>

        <div className="actions">
          {isAuthenticated ? (
            <Link to="/dashboard" className="button">
              Go to Dashboard
            </Link>
          ) : (
            <LoginButton />
          )}
        </div>
      </div>

      <div className="info">
        <p>
          <strong>SDK:</strong> @zea.cl/thalamus-js v1.0.1
        </p>
        <p>
          <strong>OAuth2 Server:</strong> {import.meta.env.VITE_THALAMUS_BASE_URL}
        </p>
      </div>
    </div>
  )
}
