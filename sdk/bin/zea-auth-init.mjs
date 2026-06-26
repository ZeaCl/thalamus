#!/usr/bin/env node

/**
 * zea-auth-init — ZEA Auth Setup CLI
 *
 * Scaffolds the environment variables needed for a frontend application 
 * to perform OAuth2 PKCE login against the ZEA Identity Provider.
 *
 * Usage: npx zea-auth-init
 */

import { randomBytes } from 'crypto'
import { writeFileSync, existsSync, readFileSync, appendFileSync } from 'fs'

const THALAMUS_URL = process.env.THALAMUS_URL || 'https://auth.zea.cl'

function base64url(b) {
  return b.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function main() {
  console.log('')
  console.log('🧠  ZEA Auth — Frontend Setup')
  console.log('')

  // Generate a unique client_id for this app
  const CLIENT_ID = 'app_' + base64url(randomBytes(8))
  
  const envContent = `VITE_ZEA_AUTH_URL=${THALAMUS_URL}\nVITE_ZEA_CLIENT_ID=${CLIENT_ID}\n`
  
  if (existsSync('.env.local')) {
    const current = readFileSync('.env.local', 'utf8')
    if (!current.includes('VITE_ZEA_CLIENT_ID')) {
      appendFileSync('.env.local', `\n${envContent}`)
    }
  } else {
    writeFileSync('.env.local', envContent)
  }

  console.log('✅  Setup complete!')
  console.log('   Variables appended to .env.local:')
  console.log(`   - VITE_ZEA_AUTH_URL=${THALAMUS_URL}`)
  console.log(`   - VITE_ZEA_CLIENT_ID=${CLIENT_ID}`)
  console.log('')
  console.log('   Your React components (e.g. <LoginButton />) are now ready to perform PKCE login.')
  console.log('   (Note: If you are building a backend/agent, do NOT use this script. Use `zea token create` to get a PAT instead).')
  console.log('')
}

main().catch((err) => {
  console.error('Fatal error:', err)
  process.exit(1)
})
