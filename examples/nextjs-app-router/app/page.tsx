/**
 * Landing Page with Thalamus-inspired design
 */

export default function Home() {
  return (
    <main>
      {/* Hero Section */}
      <div className="relative isolate overflow-hidden bg-base-100">
        {/* Background gradient */}
        <div className="absolute inset-0 -z-10 overflow-hidden">
          <svg
            className="absolute left-[max(50%,25rem)] top-0 h-[64rem] w-[128rem] -translate-x-1/2 stroke-base-content/10 [mask-image:radial-gradient(64rem_64rem_at_top,white,transparent)]"
            aria-hidden="true"
          >
            <defs>
              <pattern
                id="hero-pattern"
                width="200"
                height="200"
                x="50%"
                y="-1"
                patternUnits="userSpaceOnUse"
              >
                <path d="M100 200V.5M.5 .5H200" fill="none" />
              </pattern>
            </defs>
            <svg x="50%" y="-1" className="overflow-visible fill-base-content/5">
              <path
                d="M-100.5 0h201v201h-201Z M699.5 0h201v201h-201Z M499.5 400h201v201h-201Z M-300.5 600h201v201h-201Z"
                strokeWidth="0"
              />
            </svg>
            <rect width="100%" height="100%" strokeWidth="0" fill="url(#hero-pattern)" />
          </svg>
        </div>

        <div className="mx-auto max-w-7xl px-6 pb-24 pt-10 sm:pb-32 lg:flex lg:px-8 lg:py-40">
          <div className="mx-auto max-w-2xl flex-shrink-0 lg:mx-0 lg:max-w-xl lg:pt-8">
            {/* Logo */}
            <div className="flex items-center gap-3 mb-10">
              <svg className="h-16 w-16 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                />
              </svg>
              <div>
                <h1 className="text-4xl font-bold tracking-tight text-base-content">Next.js SDK</h1>
                <p className="text-sm text-primary font-medium">Thalamus Example</p>
              </div>
            </div>

            <h2 className="text-4xl font-bold tracking-tight text-base-content sm:text-6xl">
              OAuth2 Authentication Made Simple
            </h2>
            <p className="mt-6 text-lg leading-8 text-base-content/70">
              Example application demonstrating seamless OAuth2 integration with ZEA Thalamus using the TypeScript SDK. Built with Next.js 14 and React Server Components.
            </p>

            <div className="mt-10 flex flex-wrap items-center gap-4">
              <a href="/api/auth/login" className="btn btn-primary btn-lg">
                <svg className="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
                  />
                </svg>
                Sign In with Thalamus
              </a>
              <a href="/docs" className="btn btn-secondary btn-lg">
                <svg className="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                  />
                </svg>
                Documentation
              </a>
              <a
                href="https://github.com/zea/thalamus"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-ghost btn-lg"
              >
                <svg className="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
                </svg>
                View Source
              </a>
            </div>

            {/* Stats */}
            <div className="mt-10 flex items-center gap-x-8">
              <div>
                <div className="text-3xl font-bold text-primary">SDK</div>
                <div className="text-sm text-base-content/70">Zero Dependencies</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary">OAuth2</div>
                <div className="text-sm text-base-content/70">2.0 Compliant</div>
              </div>
              <div>
                <div className="text-3xl font-bold text-primary">TS</div>
                <div className="text-sm text-base-content/70">Full Types</div>
              </div>
            </div>
          </div>

          {/* Feature Cards on the Right */}
          <div className="mx-auto mt-16 flex max-w-2xl sm:mt-24 lg:ml-10 lg:mt-0 lg:max-w-xl">
            <div className="w-full">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                {/* Feature Card 1 */}
                <div className="card bg-base-200 shadow-xl hover:shadow-2xl">
                  <div className="card-body p-6">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="rounded-lg bg-primary/10 p-2">
                        <svg
                          className="h-5 w-5 text-primary"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                          />
                        </svg>
                      </div>
                      <h3 className="text-sm font-bold text-base-content">Secure by Default</h3>
                    </div>
                    <p className="text-xs text-base-content/70">
                      httpOnly cookies, CSRF protection, and secure token storage out of the box.
                    </p>
                  </div>
                </div>

                {/* Feature Card 2 */}
                <div className="card bg-base-200 shadow-xl hover:shadow-2xl">
                  <div className="card-body p-6">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="rounded-lg bg-secondary/10 p-2">
                        <svg
                          className="h-5 w-5 text-secondary"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                            d="M13 10V3L4 14h7v7l9-11h-7z"
                          />
                        </svg>
                      </div>
                      <h3 className="text-sm font-bold text-base-content">Fast Integration</h3>
                    </div>
                    <p className="text-xs text-base-content/70">
                      Simple SDK API. Add OAuth2 to your app in minutes, not hours.
                    </p>
                  </div>
                </div>

                {/* Feature Card 3 */}
                <div className="card bg-base-200 shadow-xl hover:shadow-2xl">
                  <div className="card-body p-6">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="rounded-lg bg-accent/10 p-2">
                        <svg
                          className="h-5 w-5 text-accent"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                          />
                        </svg>
                      </div>
                      <h3 className="text-sm font-bold text-base-content">TypeScript Native</h3>
                    </div>
                    <p className="text-xs text-base-content/70">
                      Full type safety with comprehensive TypeScript definitions included.
                    </p>
                  </div>
                </div>

                {/* Feature Card 4 */}
                <div className="card bg-base-200 shadow-xl hover:shadow-2xl">
                  <div className="card-body p-6">
                    <div className="flex items-center gap-2 mb-2">
                      <div className="rounded-lg bg-success/10 p-2">
                        <svg
                          className="h-5 w-5 text-success"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth="2"
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </div>
                      <h3 className="text-sm font-bold text-base-content">Production Ready</h3>
                    </div>
                    <p className="text-xs text-base-content/70">
                      Battle-tested, RFC compliant, and ready for production deployments.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Code Example Section */}
      <div className="bg-base-200 py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto max-w-2xl lg:text-center">
            <h2 className="text-base font-semibold leading-7 text-primary">Simple Integration</h2>
            <p className="mt-2 text-3xl font-bold tracking-tight text-base-content sm:text-4xl">
              Three lines of code
            </p>
            <p className="mt-6 text-lg leading-8 text-base-content/70">
              That's all it takes to add OAuth2 authentication to your Next.js app with our SDK.
            </p>
          </div>

          <div className="mx-auto mt-16 max-w-3xl">
            <div className="mockup-code bg-neutral text-neutral-content shadow-2xl">
              <pre data-prefix="1"><code>import {'{'} ThalamusClient {'}'} from '@zea.cl/thalamus-js'</code></pre>
              <pre data-prefix="2"><code></code></pre>
              <pre data-prefix="3"><code>const thalamus = new ThalamusClient({'{'}</code></pre>
              <pre data-prefix="4"><code>  clientId: process.env.THALAMUS_CLIENT_ID,</code></pre>
              <pre data-prefix="5"><code>  redirectUri: 'http://localhost:3000/auth/callback',</code></pre>
              <pre data-prefix="6"><code>  baseUrl: 'http://localhost:4000',</code></pre>
              <pre data-prefix="7"><code>{'})'}</code></pre>
              <pre data-prefix="8"><code></code></pre>
              <pre data-prefix="9" className="text-success"><code>// That's it! Ready to authenticate users.</code></pre>
            </div>
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="bg-base-100">
        <div className="px-6 py-24 sm:px-6 sm:py-32 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-base-content sm:text-4xl">
              Ready to try it?
            </h2>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-base-content/70">
              Sign in with Thalamus to see the full OAuth2 flow in action. View your profile, token information, and more.
            </p>
            <div className="mt-10 flex items-center justify-center gap-x-6">
              <a href="/api/auth/login" className="btn btn-primary btn-lg">
                <svg className="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"
                  />
                </svg>
                Get Started
              </a>
              <a
                href="https://github.com/zea/thalamus/tree/main/examples/nextjs-app-router"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-ghost btn-lg"
              >
                View Code
                <svg className="h-5 w-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M14 5l7 7m0 0l-7 7m7-7H3"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="bg-base-200">
        <div className="mx-auto max-w-7xl px-6 py-12 md:flex md:items-center md:justify-between lg:px-8">
          <div className="flex justify-center space-x-6 md:order-2">
            <span className="text-xs text-base-content/70">
              Built with Next.js 14 & @zea.cl/thalamus-js SDK
            </span>
          </div>
          <div className="mt-8 md:order-1 md:mt-0">
            <p className="text-center text-xs leading-5 text-base-content/70">
              © 2024 Thalamus OAuth2 Example. Powered by ZEA Thalamus.
            </p>
          </div>
        </div>
      </footer>
    </main>
  )
}
