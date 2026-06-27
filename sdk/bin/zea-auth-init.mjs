#!/usr/bin/env node

/**
 * zea-auth-init — ZEA Auth Setup CLI
 *
 * Scaffolds the environment variables needed for a frontend application 
 * to perform OAuth2 PKCE login against the ZEA Identity Provider.
 *
 * Usage: 
 *   npx zea-auth-init
 *   npx zea-auth-init --org 2 --name "sudlich-app"
 */

import { randomBytes, createHash } from 'crypto'
import { writeFileSync, existsSync, readFileSync, appendFileSync } from 'fs'
import http from 'http'
import { exec } from 'child_process'
import path from 'path'
import readline from 'readline'

const THALAMUS_URL = process.env.THALAMUS_URL || 'https://auth.zea.cl'
const CLI_CLIENT_ID = 'thalamus_cli'
const PORT = 4005
const REDIRECT_URI = `http://localhost:${PORT}/callback`

function base64URLEncode(buffer) {
  return buffer.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function generatePKCE() {
  const verifier = base64URLEncode(randomBytes(32));
  const challenge = base64URLEncode(createHash('sha256').update(verifier).digest());
  return { verifier, challenge };
}

function openBrowser(url) {
  const platform = process.platform;
  let command;
  if (platform === 'win32') command = `start "" "${url}"`;
  else if (platform === 'darwin') command = `open "${url}"`;
  else command = `xdg-open "${url}"`;
  
  exec(command);
}

function askQuestion(query) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => rl.question(query, ans => {
    rl.close();
    resolve(ans);
  }));
}

async function main() {
  const args = process.argv.slice(2);
  let cliOrgArg = null;
  let cliAppName = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--org' && args[i + 1]) {
      cliOrgArg = args[i + 1];
      i++;
    } else if (args[i] === '--name' && args[i + 1]) {
      cliAppName = args[i + 1];
      i++;
    }
  }

  console.log('\n🧠  ZEA Auth — Frontend Setup (CLI Login)\n');

  const { verifier, challenge } = generatePKCE();
  const state = base64URLEncode(randomBytes(16));

  const authUrl = `${THALAMUS_URL}/oauth/authorize?client_id=${CLI_CLIENT_ID}&response_type=code&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&code_challenge_method=S256&code_challenge=${challenge}&state=${state}`;

  console.log('⏳ Waiting for authentication in the browser...');
  console.log(`(If it doesn't open automatically, click here: ${authUrl})\n`);
  
  openBrowser(authUrl);

  const authCode = await new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      if (req.url.startsWith('/callback')) {
        const url = new URL(req.url, `http://localhost:${PORT}`);
        const code = url.searchParams.get('code');
        const returnedState = url.searchParams.get('state');

        if (returnedState !== state) {
          res.writeHead(400);
          res.end('Invalid state parameter.');
          reject(new Error('Invalid state'));
          return;
        }

        const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ZEA Auth</title>
  <style>
    body {
      background-color: #0d1117;
      color: #e6edf3;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .container {
      text-align: center;
      padding: 3rem;
      border: 1px solid #30363d;
      border-radius: 12px;
      background-color: #161b22;
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
    h2 { margin-top: 0; color: #ffffff; letter-spacing: -0.5px; }
    p { color: #8b949e; margin-bottom: 0; font-size: 16px; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: 2px; color: #ffffff; margin-bottom: 24px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">
      <svg width="120" height="36" viewBox="0 0 60 18" fill="none" xmlns="http://www.w3.org/2000/svg"><g opacity="0.9"><path opacity="0.9" d="M13.5064 2.1219H1.50961V9.91821e-05H17.0022V2.1219L4.2903 14.5384H17.0817V16.896H0V14.7742L13.5064 2.1219Z" fill="white"/><path opacity="0.9" d="M23.9937 6.837V2.3576H35.276V0H21.2924V17.0532H35.355V14.6956H23.9937V9.1946H32.813V6.837H23.9937Z" fill="white"/><path opacity="0.9" d="M50.292 4.0865L56.806 16.9746H59.746L51.165 0H48.226L39.725 16.9746H42.585L49.1 4.0865H50.292Z" fill="white"/></g></svg>
    </div>
    <h2>Login Successful!</h2>
    <p>You can safely close this window and return to your terminal.</p>
  </div>
</body>
</html>`;
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(html);
        server.close();
        resolve(code);
      }
    });
    server.listen(PORT);
  });

  console.log('✅ Authenticated successfully!');
  console.log('⏳ Exchanging code for token...');

  // Exchange code for token
  const tokenRes = await fetch(`${THALAMUS_URL}/oauth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      client_id: CLI_CLIENT_ID,
      code: authCode,
      redirect_uri: REDIRECT_URI,
      code_verifier: verifier
    })
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    console.error('Failed to get token:', err);
    process.exit(1);
  }

  const tokenData = await tokenRes.json();
  const accessToken = tokenData.access_token;

  console.log('⏳ Fetching your organizations...');
  // Fetch organizations
  const orgsRes = await fetch(`${THALAMUS_URL}/api/organizations`, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });

  if (!orgsRes.ok) {
    console.error('Failed to fetch organizations:', await orgsRes.text());
    process.exit(1);
  }

  const orgsResponseData = await orgsRes.json();
  const orgs = orgsResponseData.data || orgsResponseData;

  if (!orgs || orgs.length === 0) {
    console.error('No organizations found for this user.');
    process.exit(1);
  }

  let selectedOrgId = orgs[0].id;

  if (cliOrgArg) {
    const idx = parseInt(cliOrgArg, 10) - 1;
    if (!isNaN(idx) && orgs[idx]) {
      selectedOrgId = orgs[idx].id;
      console.log(`\nUsing organization from CLI argument (by index): ${orgs[idx].name}`);
    } else {
      const foundOrg = orgs.find(o => o.name.toLowerCase().includes(cliOrgArg.toLowerCase()));
      if (foundOrg) {
        selectedOrgId = foundOrg.id;
        console.log(`\nUsing organization from CLI argument (by name match): ${foundOrg.name}`);
      } else {
        console.warn(`\n⚠️  CLI organization '${cliOrgArg}' not found. Falling back to default.`);
      }
    }
  } else if (orgs.length > 1) {
    console.log('\nYou belong to multiple organizations:');
    orgs.forEach((org, idx) => console.log(`  ${idx + 1}) ${org.name} (${org.id})`));
    const orgIndexStr = await askQuestion('\nSelect organization by number (default: 1): ');
    const idx = parseInt(orgIndexStr, 10) - 1;
    if (!isNaN(idx) && orgs[idx]) {
      selectedOrgId = orgs[idx].id;
    }
  } else {
    console.log(`\nDefaulting to your only organization: ${orgs[0].name}`);
  }

  let appName = cliAppName;
  if (!appName) {
    const defaultName = path.basename(process.cwd()) + ' Frontend';
    const answer = await askQuestion(`\nEnter a name for this new Frontend Application (default: ${defaultName}): `);
    appName = answer.trim() || defaultName;
  } else {
    console.log(`\nUsing application name from CLI argument: ${appName}`);
  }

  console.log('\n⏳ Registering application in Thalamus...');
  // Create application
  const createRes = await fetch(`${THALAMUS_URL}/api/clients`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    },
    body: JSON.stringify({
      name: appName,
      organization_id: selectedOrgId,
      client_type: 'public',
      redirect_uris: ['http://localhost:5173/auth/callback', 'http://localhost:3000/auth/callback'],
      scopes: ['openid', 'profile', 'email']
    })
  });

  if (!createRes.ok) {
    console.error('Failed to create application:', await createRes.text());
    process.exit(1);
  }

  const newClientData = await createRes.json();
  const newClient = newClientData.data || newClientData;
  const newClientId = newClient.client_id_string || newClient.id;

  const envContent = `VITE_ZEA_AUTH_URL=${THALAMUS_URL}\nVITE_ZEA_CLIENT_ID=${newClientId}\n`;
  
  if (existsSync('.env.local')) {
    const current = readFileSync('.env.local', 'utf8');
    if (!current.includes('VITE_ZEA_CLIENT_ID')) {
      appendFileSync('.env.local', `\n${envContent}`);
    } else {
      console.log('\n⚠️  VITE_ZEA_CLIENT_ID already exists in .env.local. Please update it manually to:');
      console.log(newClientId);
    }
  } else {
    writeFileSync('.env.local', envContent);
  }

  console.log('\n✅ Setup complete! Application officially registered in Thalamus.');
  console.log('   Variables set for .env.local:');
  console.log(`   - VITE_ZEA_AUTH_URL=${THALAMUS_URL}`);
  console.log(`   - VITE_ZEA_CLIENT_ID=${newClientId}`);
  console.log('\n   Your React components are now ready to perform PKCE login.');
}

main().catch((err) => {
  console.error('\nFatal error:', err);
  process.exit(1);
});
