#!/usr/bin/env node

/**
 * thalamus-init — ZEA Thalamus "from zero" setup CLI
 *
 * Starts a local server, opens browser to Thalamus register/login,
 * waits for OAuth callback, saves credentials, and exits.
 *
 * Usage: npx thalamus-init
 */

import http from 'http'
import { randomBytes, createHash } from 'crypto'
import { exec } from 'child_process'
import { writeFileSync } from 'fs'

const THALAMUS_URL = process.env.THALAMUS_URL || 'http://auth.zea.localhost'
const ORG_NAME = process.env.ZEA_ORG_NAME || 'My Organization'
const PORT = parseInt(process.env.PORT || '5399', 10)
// Generate a unique client_id for this app
const CLIENT_ID = 'app_' + base64url(randomBytes(8))

function base64url(b) {
  return b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function sha256(plain) {
  return createHash('sha256').update(plain).digest()
}

async function main() {
  const verifier = base64url(randomBytes(32))
  const challenge = base64url(sha256(verifier))
  const state = base64url(randomBytes(16))

  console.log('')
  console.log('🧠  ZEA Thalamus — Setup')
  console.log('')
  console.log('   Opening browser to register or login...')
  console.log('')

  const server = http.createServer()

  await new Promise((resolve, reject) => {
    server.listen(PORT, () => {
      resolve()
    })
    server.on('error', reject)
  })

  const addr = server.address()
  const actualPort = typeof addr === 'object' ? addr.port : PORT
  const actualRedirect = `http://localhost:${actualPort}/callback`

  // Don't pass client_id — Thalamus creates a new one during registration
  const params = new URLSearchParams({
    redirect_uri: actualRedirect,
    response_type: 'code',
    scope: 'openid profile email',
    state,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    org_name: ORG_NAME,
    app_origin: `http://localhost:${actualPort}`,
    client_id: CLIENT_ID,
  })

  const registerUrl = `${THALAMUS_URL}/register?return_to=${encodeURIComponent('/oauth/authorize?' + params.toString())}`

  const cmd = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start' : 'xdg-open'
  exec(`${cmd} "${registerUrl}"`, (err) => {
    if (err) console.log('   Could not open browser. Visit:', registerUrl)
  })

  server.on('request', async (req, res) => {
    const url = new URL(req.url || '', `http://localhost:${actualPort}`)

    if (url.pathname === '/callback') {
      const code = url.searchParams.get('code')
      const returnedState = url.searchParams.get('state')

      if (!code || returnedState !== state) {
        res.writeHead(400, { 'Content-Type': 'text/html' })
        res.end('<h1>Invalid callback</h1>')
        server.close()
        process.exit(1)
      }

      try {
        const tokenRes = await fetch(`${THALAMUS_URL}/oauth/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            grant_type: 'authorization_code',
            client_id: CLIENT_ID,
            code,
            code_verifier: verifier,
            redirect_uri: actualRedirect,
          }),
        })

        const data = await tokenRes.json()

        if (data.access_token) {
          const config = {
            clientId: CLIENT_ID,
            redirectUri: actualRedirect,
            accessToken: data.access_token,
            refreshToken: data.refresh_token || null,
            expiresAt: Date.now() + (data.expires_in || 3600) * 1000,
            baseUrl: THALAMUS_URL,
          }

          writeFileSync('.zea-config.json', JSON.stringify(config, null, 2))

          // Auto-add to .gitignore
          const { existsSync, readFileSync, appendFileSync } = await import('fs')
          const gitignore = '.gitignore'
          const entry = '.zea-config.json'
          if (existsSync(gitignore)) {
            const content = readFileSync(gitignore, 'utf8')
            if (!content.includes(entry)) appendFileSync(gitignore, `\n${entry}\n`)
          } else {
            appendFileSync(gitignore, `${entry}\n`)
          }

          res.writeHead(200, { 'Content-Type': 'text/html' })
          res.end(`<!DOCTYPE html><html><head><title>ZEA Setup</title><style>body{font-family:system-ui,sans-serif;background:#0B0D13;color:#e6edf3;display:flex;align-items:center;justify-content:center;min-height:100vh;text-align:center;flex-direction:column;gap:16px}h1{color:#3fb950;font-size:24px}p{color:#8b949e;font-size:14px;max-width:400px}code{background:#161b22;padding:4px 8px;border-radius:4px;font-size:12px}</style></head><body><h1>Setup Complete!</h1><p>Your app is connected to ZEA Thalamus.</p><p>Config saved to <code>.zea-config.json</code></p><p>Close this window and run <code>npm run dev</code></p></body></html>`)

          console.log('')
          console.log('✅  Setup complete!')
          console.log('   Token saved to .zea-config.json')
          console.log('')

          setTimeout(() => { server.close(); process.exit(0) }, 1000)
        } else {
          throw new Error(data.error_description || data.error || 'Token exchange failed')
        }
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'text/html' })
        res.end(`<h1>Setup failed</h1><p>${err.message}</p>`)
        console.error('❌', err.message)
        server.close()
        process.exit(1)
      }
    } else {
      res.writeHead(404)
      res.end('Not found')
    }
  })
}

main().catch((err) => {
  console.error('Fatal error:', err)
  process.exit(1)
})
