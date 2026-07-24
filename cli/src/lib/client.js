import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import http from 'http';
import crypto from 'crypto';
import open from 'open';
import { zeaFetch } from './http.js';

// .zea.localhost → 127.0.0.1 resolution is handled by zeaFetch in lib/http.js
export const CONFIG_DIR = path.join(os.homedir(), '.config', 'zea');
export const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

export async function loadConfig() {
  try {
    const data = await fs.readFile(CONFIG_FILE, 'utf8');
    return JSON.parse(data);
  } catch (e) {
    return {};
  }
}

export async function saveConfig(config) {
  await fs.mkdir(CONFIG_DIR, { recursive: true });
  await fs.writeFile(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf8');
}

export async function getClient() {
  const config = await loadConfig();
  const token = process.env.ZEA_PAT || process.env.THALAMUS_PAT || process.env.ZEA_TOKEN || config.token;
  const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || config.apiUrl || 'https://auth.zea.cl';
  const activeOrgId = config.activeOrgId || process.env.ZEA_ORG_ID || null;
  const cerebelumUrl = process.env.ZEA_CEREBELUM_URL || process.env.CEREBELUM_URL || config.cerebelumUrl || 'http://cerebelum.zea.localhost';
  const ventureUrl = process.env.ZEA_VENTURE_URL || config.ventureUrl || 'http://venture.zea.localhost';
  const sduiUrl = process.env.ZEA_SDUI_URL || config.sduiUrl || 'http://sdui.zea.localhost';
  const appsUrl = process.env.ZEA_APPS_URL || config.appsUrl || 'http://apps.zea.localhost';
  const gliaUrl = process.env.ZEA_GLIA_URL || config.gliaUrl || 'http://localhost:4002';
  const gliaWsUrl = process.env.ZEA_GLIA_WS_URL || config.gliaWsUrl || 'ws://localhost:4002/socket/websocket';
  const sensorUrl = process.env.ZEA_SENSOR_URL || config.sensorUrl || 'http://sensor.zea.localhost';
  const deepseekKey = process.env.DEEPSEEK_API_KEY || config.deepseek_key || config.deepseekKey || null;

  if (!token) {
    throw new Error('Not authenticated. Please run "zea auth login" or set ZEA_PAT.');
  }

  const isLocalhost = gliaUrl.includes('localhost') || gliaUrl.includes('127.0.0.1');

  return {
    apiUrl,
    cerebelumUrl,
    ventureUrl,
    sduiUrl,
    appsUrl,
    gliaUrl,
    gliaWsUrl,
    sensorUrl,
    token,
    deepseekKey,
    isLocalhost,
    activeOrgId,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };
}

export async function handleDirectLogin(options) {
  const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || options.url || 'https://auth.zea.cl';
  const email = options.email;
  const password = options.password;
  
  try {
    const response = await zeaFetch(`${apiUrl}/api/public/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    
    if (!response.ok) {
      const errData = await response.json();
      throw new Error(errData.error_description || errData.error || `Login failed: ${response.status}`);
    }
    
    const data = await response.json();
    const config = await loadConfig();
    config.token = data.access_token;
    config.refreshToken = data.refresh_token;
    config.apiUrl = apiUrl;
    
    const userinfoResponse = await zeaFetch(`${apiUrl}/oauth/userinfo`, {
      headers: { 'Authorization': `Bearer ${data.access_token}` }
    });
    
    if (userinfoResponse.ok) {
      const userinfo = await userinfoResponse.json();
      if (userinfo.organizations && userinfo.organizations.length > 0) {
        config.activeOrgId = userinfo.organizations[0].id;
      }
    }
    
    await saveConfig(config);
    console.log('Successfully authenticated with ZEA Platform!');
    console.log(`User: ${data.user.email} (${data.user.name})`);
    if (data.organization) {
      console.log(`Organization: ${data.organization.name}`);
    }
  } catch (error) {
    console.error('Login failed:', error.message);
    process.exit(1);
  }
}

export async function handleLogin(options) {
  const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || options.url || 'https://auth.zea.cl';

  const codeVerifier = crypto.randomBytes(32).toString('base64url');
  const codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');
  const state = crypto.randomBytes(16).toString('hex');

  let port, redirectUri;

  console.log('Starting local authentication flow...');
  
  const server = http.createServer(async (req, res) => {
    const urlObj = new URL(req.url, `http://localhost:${port}`);
    if (urlObj.pathname === '/callback') {
      const code = urlObj.searchParams.get('code');
      const returnedState = urlObj.searchParams.get('state');

      if (returnedState !== state) {
        res.writeHead(400, { 'Content-Type': 'text/html' });
        res.end('<h1>Authentication Error</h1><p>State mismatch. Potential CSRF attack detected.</p>');
        server.close();
        process.exit(1);
      }

      try {
        const tokenUrl = `${apiUrl}/oauth/token`;
        const params = new URLSearchParams({
          grant_type: 'authorization_code',
          code,
          redirect_uri: redirectUri,
          client_id: 'thalamus_cli',
          code_verifier: codeVerifier
        });

        const tokenResponse = await zeaFetch(tokenUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: params.toString()
        });

        if (!tokenResponse.ok) {
          const errText = await tokenResponse.text();
          throw new Error(`Token exchange failed: ${errText}`);
        }

        const tokenData = await tokenResponse.json();
        const config = await loadConfig();
        
        config.token = tokenData.access_token;
        config.refreshToken = tokenData.refresh_token;
        config.apiUrl = apiUrl;
        
        const userinfoResponse = await zeaFetch(`${apiUrl}/oauth/userinfo`, {
          headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
        });

        if (userinfoResponse.ok) {
          const userinfo = await userinfoResponse.json();
          if (userinfo.organizations && userinfo.organizations.length > 0) {
            config.activeOrgId = userinfo.organizations[0].id;
          }
        }

        await saveConfig(config);

        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end('<h1>Authentication Successful</h1><p>You can close this tab and return to the terminal.</p>');
        console.log('Successfully authenticated with ZEA Platform!');
        
        setTimeout(() => {
          server.close();
          process.exit(0);
        }, 1000);

      } catch (error) {
        res.writeHead(500, { 'Content-Type': 'text/html' });
        res.end(`<h1>Authentication Failed</h1><p>${error.message}</p>`);
        console.error('Error during token exchange:', error.message);
        setTimeout(() => {
          server.close();
          process.exit(1);
        }, 1000);
      }
    }
  });

  server.listen(0, async () => {
    port = server.address().port;
    redirectUri = `http://localhost:${port}/callback`;
    const authorizeUrl = `${apiUrl}/oauth/authorize?response_type=code&client_id=thalamus_cli&redirect_uri=${encodeURIComponent(redirectUri)}&scope=openid%20profile%20zea:read%20zea:write&state=${state}&code_challenge=${codeChallenge}&code_challenge_method=S256`;
    console.log(`Opening browser to log in...`);
    console.log(`URL: ${authorizeUrl}`);
    await open(authorizeUrl);
  });

  server.on('error', (e) => {
    if (e.code === 'EADDRINUSE') {
      console.error('❌ All ports in use. Please free a port and try again.');
    } else {
      console.error('❌ Failed to start local server:', e.message);
    }
    process.exit(1);
  });
}

export async function handleDeviceLogin(options) {
  const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || options.url || 'https://auth.zea.cl';
  const clientId = 'thalamus_cli';

  console.log('Starting device authentication flow...\n');

  // Step 1: Request device code
  let deviceResponse;
  try {
    deviceResponse = await zeaFetch(`${apiUrl}/oauth/device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `client_id=${encodeURIComponent(clientId)}&scope=openid%20profile%20email%20zea%3Aread%20zea%3Awrite`
    });
  } catch (e) {
    console.error(`❌ Cannot reach ${apiUrl}. Is the server running?`);
    process.exit(1);
  }

  if (!deviceResponse.ok) {
    const err = await deviceResponse.json().catch(() => ({}));
    console.error(`❌ Device authorization failed: ${err.error_description || err.error || `HTTP ${deviceResponse.status}`}`);
    process.exit(1);
  }

  const deviceData = await deviceResponse.json();
  const { device_code, user_code, verification_uri, interval } = deviceData;

  // Step 2: Show the code to the user
  console.log('┌─────────────────────────────────────────────┐');
  console.log('│                                             │');
  console.log(`│   Open:  ${verification_uri.padEnd(37)}│`);
  console.log(`│   Code:  ${user_code.padEnd(37)}│`);
  console.log('│                                             │');
  console.log('└─────────────────────────────────────────────┘');
  console.log('');

  // Step 3: Try to open browser
  try {
    const open = (await import('open')).default;
    await open(`${verification_uri}?code=${encodeURIComponent(user_code)}`);
    console.log('Browser opened automatically. If not, use the URL above.\n');
  } catch {
    console.log('Copy the URL above into your browser.\n');
  }

  // Step 4: Poll for authorization
  const pollInterval = (interval || 5) * 1000;
  const maxAttempts = 120; // 10 minutes max (120 × 5s)

  console.log('Waiting for authorization...');

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    await sleep(pollInterval);

    try {
      const tokenResponse = await zeaFetch(`${apiUrl}/oauth/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
          device_code,
          client_id: clientId
        }).toString()
      });

      if (tokenResponse.ok) {
        const tokenData = await tokenResponse.json();

        // Save config
        const config = await loadConfig();
        config.token = tokenData.access_token;
        config.refreshToken = tokenData.refresh_token;
        config.apiUrl = apiUrl;

        // Get user info
        try {
          const userResp = await zeaFetch(`${apiUrl}/oauth/userinfo`, {
            headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
          });
          if (userResp.ok) {
            const userinfo = await userResp.json();
            if (userinfo.organizations && userinfo.organizations.length > 0) {
              config.activeOrgId = userinfo.organizations[0].id;
            }
          }
        } catch { /* non-critical */ }

        await saveConfig(config);
        console.log('✅ Successfully authenticated with ZEA Platform!');
        return;
      }

      const errorData = await tokenResponse.json().catch(() => ({}));

      if (errorData.error === 'authorization_pending') {
        // Still waiting — dots for progress
        if (attempt % 6 === 0) process.stdout.write('.');
        continue;
      }

      if (errorData.error === 'slow_down') {
        // Server asked us to slow down — increase interval
        await sleep(pollInterval);
        continue;
      }

      if (errorData.error === 'expired_token') {
        console.error('\n❌ Device code expired. Please run `zea thalamus login --device` again.');
        process.exit(1);
      }

      // Unknown error
      console.error(`\n❌ Authorization failed: ${errorData.error_description || errorData.error || `HTTP ${tokenResponse.status}`}`);
      process.exit(1);

    } catch (e) {
      if (attempt >= maxAttempts - 1) {
        console.error(`\n❌ Connection lost during authentication: ${e.message}`);
        process.exit(1);
      }
      // Keep trying on network errors
      process.stdout.write('!');
    }
  }

  console.error('\n❌ Timed out waiting for authorization. Please try again.');
  process.exit(1);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export async function resolveSecret(provider) {
  try {
    const config = await loadConfig();
    const token = process.env.ZEA_PAT || process.env.THALAMUS_PAT || process.env.ZEA_TOKEN || config.token;
    const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || config.apiUrl || 'https://auth.zea.cl';
    
    if (!token) return null;

    // 1. Get user_id and org_id
    const userResp = await zeaFetch(`${apiUrl}/oauth/userinfo`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!userResp.ok) return null;
    
    const userinfo = await userResp.json();
    const userId = userinfo.sub || '';
    const orgId = userinfo.organization ? userinfo.organization.id : '';

    // 2. Resolve secret from internal endpoint
    const resolveUrl = `${apiUrl}/api/internal/secrets/resolve?provider=${provider}&user_id=${userId}&org_id=${orgId}`;
    const secretResp = await zeaFetch(resolveUrl);
    if (!secretResp.ok) return null;
    
    const secretData = await secretResp.json();
    return secretData.value || null;
  } catch (e) {
    return null;
  }
}
