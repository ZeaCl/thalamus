/**
 * Dashboard Page with Thalamus-inspired design
 *
 * Protected page that displays user information and token details
 */

import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { thalamus } from '@/lib/thalamus'

export default async function Dashboard() {
  const accessToken = cookies().get('access_token')?.value

  // Redirect to login if not authenticated
  if (!accessToken) {
    redirect('/api/auth/login')
  }

  let user: any = null
  let tokenInfo: any = null
  let error: string | null = null

  try {
    // Get user information
    user = await thalamus.tokens.getUserInfo(accessToken)

    // Get token metadata
    tokenInfo = await thalamus.tokens.introspect(accessToken)
  } catch (err: any) {
    error = err.message
    console.error('Error fetching user data:', err)
  }

  if (error) {
    return (
      <main className="min-h-screen bg-base-200 flex flex-col items-center justify-center p-8">
        <div className="card bg-base-100 shadow-2xl max-w-2xl w-full">
          <div className="card-body text-center">
            <div className="flex justify-center mb-4">
              <svg className="h-16 w-16 text-error" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
            </div>
            <h1 className="text-3xl font-bold text-error mb-2">Authentication Error</h1>
            <p className="text-base-content/70 mb-6">{error}</p>
            <div className="card-actions justify-center">
              <a href="/api/auth/login" className="btn btn-primary btn-lg">
                <svg className="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
                  />
                </svg>
                Sign In Again
              </a>
            </div>
          </div>
        </div>
      </main>
    )
  }

  // Calculate token expiration time
  const expiresAt = new Date(tokenInfo.exp * 1000)
  const issuedAt = new Date(tokenInfo.iat * 1000)
  const now = new Date()
  const timeRemaining = Math.floor((expiresAt.getTime() - now.getTime()) / 1000 / 60) // minutes

  return (
    <main className="min-h-screen bg-base-200">
      {/* Header */}
      <div className="bg-base-100 border-b border-base-300">
        <div className="px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div className="flex items-center gap-3">
              <svg className="h-12 w-12 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                />
              </svg>
              <div>
                <h1 className="text-2xl font-bold text-base-content">Dashboard</h1>
                <p className="text-sm text-primary font-medium">Thalamus OAuth2</p>
              </div>
            </div>
            <div className="flex gap-3">
              <a href="/" className="btn btn-ghost btn-sm">
                <svg className="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
                  />
                </svg>
                Home
              </a>
              <a href="/api/auth/logout" className="btn btn-error btn-sm">
                <svg className="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                  />
                </svg>
                Logout
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="px-4 sm:px-6 lg:px-8 py-8">
        {/* Welcome Message */}
        <div className="mb-8">
          <h2 className="text-xl font-semibold text-base-content">
            Welcome back, {user.name || user.email}!
          </h2>
          <p className="mt-1 text-sm text-base-content/70">
            You're successfully authenticated with Thalamus OAuth2
          </p>
        </div>

        {/* User Stats Grid */}
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          {/* Email */}
          <div className="card bg-base-100 shadow">
            <div className="card-body">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <svg className="h-8 w-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-base-content/70 truncate">Email Address</dt>
                    <dd className="flex items-baseline">
                      <div className="text-sm font-semibold text-base-content truncate">{user.email}</div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          {/* Email Verified */}
          <div className="card bg-base-100 shadow">
            <div className="card-body">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <svg className="h-8 w-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-base-content/70 truncate">Email Status</dt>
                    <dd className="flex items-baseline mt-1">
                      {user.email_verified ? (
                        <span className="badge badge-success badge-sm">Verified</span>
                      ) : (
                        <span className="badge badge-warning badge-sm">Not Verified</span>
                      )}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          {/* Token Status */}
          <div className="card bg-base-100 shadow">
            <div className="card-body">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <svg className="h-8 w-8 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"
                    />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-base-content/70 truncate">Access Token</dt>
                    <dd className="flex items-baseline mt-1">
                      {tokenInfo.active ? (
                        <span className="badge badge-success badge-sm">Active</span>
                      ) : (
                        <span className="badge badge-error badge-sm">Inactive</span>
                      )}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          {/* Token Expiration */}
          <div className="card bg-base-100 shadow">
            <div className="card-body">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <svg className="h-8 w-8 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-base-content/70 truncate">Expires In</dt>
                    <dd className="flex items-baseline">
                      <div className="text-lg font-semibold text-base-content">
                        {timeRemaining > 60 ? `${Math.floor(timeRemaining / 60)}h` : `${timeRemaining}m`}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* User Information Card */}
        <div className="card bg-base-100 shadow mb-6">
          <div className="card-body">
            <h2 className="text-lg font-medium text-base-content mb-4">User Information</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">User ID (Subject)</p>
                <p className="font-mono text-sm text-base-content bg-base-200 px-3 py-2 rounded">{user.sub}</p>
              </div>
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">Email Address</p>
                <p className="font-mono text-sm text-base-content bg-base-200 px-3 py-2 rounded">{user.email}</p>
              </div>
              {user.name && (
                <div>
                  <p className="text-sm font-medium text-base-content/70 mb-1">Full Name</p>
                  <p className="text-sm text-base-content bg-base-200 px-3 py-2 rounded">{user.name}</p>
                </div>
              )}
              {user.organization_id && (
                <div>
                  <p className="text-sm font-medium text-base-content/70 mb-1">Organization ID</p>
                  <p className="font-mono text-sm text-base-content bg-base-200 px-3 py-2 rounded">
                    {user.organization_id}
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Token Information Card */}
        <div className="card bg-base-100 shadow mb-6">
          <div className="card-body">
            <h2 className="text-lg font-medium text-base-content mb-4">Token Information</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">Client ID</p>
                <p className="font-mono text-sm text-base-content bg-base-200 px-3 py-2 rounded">
                  {tokenInfo.client_id}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">Scopes</p>
                <div className="flex flex-wrap gap-2">
                  {tokenInfo.scope.split(' ').map((scope: string) => (
                    <span key={scope} className="badge badge-primary badge-sm">
                      {scope}
                    </span>
                  ))}
                </div>
              </div>
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">Issued At</p>
                <p className="text-sm text-base-content bg-base-200 px-3 py-2 rounded">
                  {issuedAt.toLocaleString()}
                </p>
              </div>
              <div>
                <p className="text-sm font-medium text-base-content/70 mb-1">Expires At</p>
                <p className="text-sm text-base-content bg-base-200 px-3 py-2 rounded">
                  {expiresAt.toLocaleString()}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="mb-8">
          <h2 className="text-lg font-medium text-base-content mb-4">Quick Actions</h2>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <a
              href="https://github.com/zea/thalamus"
              target="_blank"
              rel="noopener noreferrer"
              className="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="card-body">
                <div className="flex items-center">
                  <svg className="h-6 w-6 text-blue-500" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                  </svg>
                  <h3 className="ml-3 text-sm font-medium text-base-content">View Source Code</h3>
                </div>
              </div>
            </a>

            <a
              href="https://github.com/zea/thalamus/tree/main/packages/thalamus-js"
              target="_blank"
              rel="noopener noreferrer"
              className="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="card-body">
                <div className="flex items-center">
                  <svg className="h-6 w-6 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    />
                  </svg>
                  <h3 className="ml-3 text-sm font-medium text-base-content">SDK Documentation</h3>
                </div>
              </div>
            </a>

            <a
              href="/"
              className="card bg-base-100 shadow hover:shadow-lg transition-shadow cursor-pointer"
            >
              <div className="card-body">
                <div className="flex items-center">
                  <svg className="h-6 w-6 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
                    />
                  </svg>
                  <h3 className="ml-3 text-sm font-medium text-base-content">Back to Home</h3>
                </div>
              </div>
            </a>
          </div>
        </div>

        {/* JSON Debug Section */}
        <details className="collapse collapse-arrow bg-base-100 shadow">
          <summary className="collapse-title text-sm font-medium">
            Developer Debug Information
          </summary>
          <div className="collapse-content">
            <div className="space-y-6 pt-4">
              <div>
                <h3 className="text-sm font-semibold text-base-content mb-2">User Info Response:</h3>
                <div className="mockup-code text-xs">
                  <pre data-prefix=">">{JSON.stringify(user, null, 2)}</pre>
                </div>
              </div>
              <div>
                <h3 className="text-sm font-semibold text-base-content mb-2">Token Introspection Response:</h3>
                <div className="mockup-code text-xs">
                  <pre data-prefix=">">{JSON.stringify(tokenInfo, null, 2)}</pre>
                </div>
              </div>
            </div>
          </div>
        </details>
      </div>
    </main>
  )
}
