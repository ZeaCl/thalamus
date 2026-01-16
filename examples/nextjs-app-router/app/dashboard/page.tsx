/**
 * Dashboard Page
 *
 * Protected page that displays user information
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
      <main className="flex min-h-screen flex-col items-center justify-center p-24">
        <div className="max-w-2xl text-center">
          <h1 className="text-4xl font-bold mb-4 text-red-600">Error</h1>
          <p className="text-gray-600 mb-8">{error}</p>
          <a
            href="/api/auth/login"
            className="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold px-6 py-3 rounded-lg transition-colors"
          >
            Try Again
          </a>
        </div>
      </main>
    )
  }

  return (
    <main className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-4xl font-bold">Dashboard</h1>
          <a
            href="/api/auth/logout"
            className="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg transition-colors"
          >
            Logout
          </a>
        </div>

        {/* User Info Card */}
        <div className="bg-white rounded-lg shadow-md p-8 mb-6">
          <h2 className="text-2xl font-semibold mb-6">User Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-600">User ID</p>
              <p className="font-mono text-sm">{user.sub}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Email</p>
              <p className="font-mono text-sm">{user.email}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Name</p>
              <p className="font-mono text-sm">{user.name || 'N/A'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Email Verified</p>
              <p className="font-mono text-sm">
                {user.email_verified ? '✅ Yes' : '❌ No'}
              </p>
            </div>
            {user.organization_id && (
              <div>
                <p className="text-sm text-gray-600">Organization ID</p>
                <p className="font-mono text-sm">{user.organization_id}</p>
              </div>
            )}
          </div>
        </div>

        {/* Token Info Card */}
        <div className="bg-white rounded-lg shadow-md p-8">
          <h2 className="text-2xl font-semibold mb-6">Token Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-600">Token Status</p>
              <p className="font-mono text-sm">
                {tokenInfo.active ? '✅ Active' : '❌ Inactive'}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Client ID</p>
              <p className="font-mono text-sm">{tokenInfo.client_id}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Scopes</p>
              <p className="font-mono text-sm">{tokenInfo.scope}</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Expires At</p>
              <p className="font-mono text-sm">
                {new Date(tokenInfo.exp * 1000).toLocaleString()}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Issued At</p>
              <p className="font-mono text-sm">
                {new Date(tokenInfo.iat * 1000).toLocaleString()}
              </p>
            </div>
          </div>
        </div>

        {/* JSON Debug */}
        <details className="mt-6">
          <summary className="cursor-pointer text-sm text-gray-600 hover:text-gray-900">
            Show Raw JSON
          </summary>
          <div className="mt-4 space-y-4">
            <div>
              <h3 className="text-sm font-semibold mb-2">User Info:</h3>
              <pre className="bg-gray-100 p-4 rounded text-xs overflow-auto">
                {JSON.stringify(user, null, 2)}
              </pre>
            </div>
            <div>
              <h3 className="text-sm font-semibold mb-2">Token Info:</h3>
              <pre className="bg-gray-100 p-4 rounded text-xs overflow-auto">
                {JSON.stringify(tokenInfo, null, 2)}
              </pre>
            </div>
          </div>
        </details>
      </div>
    </main>
  )
}
