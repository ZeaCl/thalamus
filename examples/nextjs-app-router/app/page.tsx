/**
 * Home Page
 *
 * Landing page with login button
 */

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="max-w-2xl text-center">
        <h1 className="text-6xl font-bold mb-6">
          Next.js + Thalamus
        </h1>

        <p className="text-xl text-gray-600 mb-8">
          Example application demonstrating OAuth2 authentication with ZEA Thalamus
        </p>

        <a
          href="/api/auth/login"
          className="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold px-8 py-4 rounded-lg transition-colors"
        >
          Sign In with Thalamus
        </a>

        <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-6 border rounded-lg">
            <h3 className="font-semibold mb-2">🔒 Secure</h3>
            <p className="text-sm text-gray-600">
              OAuth2 2.0 compliant authentication
            </p>
          </div>

          <div className="p-6 border rounded-lg">
            <h3 className="font-semibold mb-2">⚡ Simple</h3>
            <p className="text-sm text-gray-600">
              Easy integration with TypeScript SDK
            </p>
          </div>

          <div className="p-6 border rounded-lg">
            <h3 className="font-semibold mb-2">🎯 Production Ready</h3>
            <p className="text-sm text-gray-600">
              Built for scale and reliability
            </p>
          </div>
        </div>
      </div>
    </main>
  )
}
