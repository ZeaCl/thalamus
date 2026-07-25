#!/usr/bin/env node
/**
 * Records API response fixtures for contract testing.
 *
 * Hits Thalamus endpoints and saves responses to cli/test/fixtures/.
 * Run once with Thalamus running and seeded:
 *
 *   cd cli && THALAMUS_API_URL=http://localhost:4100 node scripts/record-contracts.cjs
 */
const fs = require('fs');
const path = require('path');

const API = process.env.THALAMUS_API_URL || 'http://localhost:4100';
const FIXTURES_DIR = path.join(__dirname, '..', 'test', 'fixtures');
const TOKEN = process.env.THALAMUS_TOKEN || '';

// ── Endpoints to record ────────────────────────────────────────

const ENDPOINTS = [
  // Public (no auth)
  { name: 'health', path: '/api/public/health', method: 'GET' },
  { name: 'oidc-discovery', path: '/.well-known/openid-configuration', method: 'GET' },
  { name: 'jwks', path: '/.well-known/jwks.json', method: 'GET' },

  // Authenticated (require token)
  { name: 'userinfo', path: '/oauth/userinfo', method: 'GET', auth: true },
  { name: 'clients-list', path: '/api/clients', method: 'GET', auth: true },
  { name: 'users-list', path: '/api/users', method: 'GET', auth: true },
  { name: 'orgs-list', path: '/api/organizations', method: 'GET', auth: true },
  { name: 'roles-list', path: '/api/roles', method: 'GET', auth: true },
  { name: 'secrets-list', path: '/api/secrets', method: 'GET', auth: true },
  { name: 'domains-list', path: '/api/domains', method: 'GET', auth: true },
  { name: 'pats-list', path: '/api/personal-access-tokens', method: 'GET', auth: true },
  { name: 'admin-api-keys', path: '/api/admin/api-keys', method: 'GET', auth: true },
];

// ── Record ──────────────────────────────────────────────────────

async function main() {
  if (!fs.existsSync(FIXTURES_DIR)) {
    fs.mkdirSync(FIXTURES_DIR, { recursive: true });
  }

  let token = TOKEN;
  if (!token && ENDPOINTS.some(e => e.auth)) {
    // Try to get token via login
    console.log('No THALAMUS_TOKEN set. Trying login...');
    try {
      const resp = await fetch(`${API}/oauth/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'grant_type=password&client_id=internal_login&client_secret=internal_secret_do_not_expose&username=admin@zea.local&password=Admin123!'
      });
      const data = await resp.json();
      token = data.access_token;
      console.log('  Token obtained ✅');
    } catch {
      console.log('  Login failed. Record public endpoints only.');
    }
  }

  let ok = 0;
  let fail = 0;

  for (const ep of ENDPOINTS) {
    const url = `${API}${ep.path}`;
    const opts = {
      method: ep.method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (ep.auth && token) {
      opts.headers['Authorization'] = `Bearer ${token}`;
    }

    try {
      console.log(`  ${ep.method} ${ep.path}...`);
      const resp = await fetch(url, opts);
      const body = await resp.text();
      let json;
      try { json = JSON.parse(body); } catch { json = body; }

      const fixture = {
        _recorded_at: new Date().toISOString(),
        _endpoint: ep.path,
        _status: resp.status,
        body: json,
      };

      const filepath = path.join(FIXTURES_DIR, `${ep.name}.json`);
      fs.writeFileSync(filepath, JSON.stringify(fixture, null, 2));
      console.log(`    ✅ ${ep.name}.json (${resp.status})`);
      ok++;
    } catch (e) {
      console.log(`    ❌ ${e.message}`);
      fail++;
    }
  }

  console.log(`\n${ok} recorded, ${fail} failed`);
  if (fail > 0) process.exit(1);
}

main().catch(e => { console.error(e); process.exit(1); });
