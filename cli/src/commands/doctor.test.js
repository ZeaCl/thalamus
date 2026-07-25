import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';
import { createTestServer } from '../../test/test-server.js';

const CONFIG_DIR = path.join(os.homedir(), '.config', 'zea');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

function fakeJwt(payload = { sub: 'u1', email: 'test@test.com' }) {
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  return `${b64({ alg: 'RS256' })}.${b64(payload)}.sig`;
}

let output = '';
let server;

mock.method(console, 'error', () => {});
mock.method(process, 'exit', (code) => {
  throw new Error(`exit(${code})`);
});

describe('doctor', () => {
  beforeEach(async () => {
    output = '';
    server = createTestServer();
    mock.method(console, 'log', (...args) => { output += args.join(' ') + '\n'; });
  });

  afterEach(async () => {
    await server.stop();
    mock.restoreAll();
  });

  it('all checks pass', async () => {
    const API = await server.start();
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API, token: fakeJwt(), activeOrgId: 'org1' }));

    server.get('/api/public/health', 200, { status: 'ok', version: '1.0.0', checks: { database: 'ok', cache: 'ok' } });
    server.get('/oauth/userinfo', 200, { sub: 'u1', email: 'test@test.com', organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }], organization: { name: 'ZEA' } });
    server.post('/oauth/introspect', 200, { active: true, exp: Math.floor(Date.now() / 1000) + 3600 });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);
    await assert.rejects(() => p._subcommands['doctor']._handler(), /exit\(0\)/);
    assert.match(output, /reachable/);
    assert.match(output, /test@test\.com/);
    assert.match(output, /ZEA/);
  });

  it('unreachable server', async () => {
    const API = 'http://127.0.0.1:19999'; // nothing listening here
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API }));

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);
    try { await p._subcommands['doctor']._handler(); } catch (e) { /* exit mock */ }
    assert.match(output, /Cannot reach|Connection error/);
  });

  it('no token warning', async () => {
    const API = await server.start();
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API }));
    server.get('/api/public/health', 200, { status: 'ok' });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);
    try { await p._subcommands['doctor']._handler(); } catch (e) { /* exit mock */ }
    assert.match(output, /No token/);
  });

  it('domain roles from JWT', async () => {
    const API = await server.start();
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({
      apiUrl: API,
      token: fakeJwt({ sub: 'u1', email: 'test@test.com', domain_roles: [{ domain: 'fund', role: 'admin', org_id: 'org12345', scopes: ['read'] }] }),
      activeOrgId: 'org1'
    }));

    server.get('/api/public/health', 200, { status: 'ok' });
    server.get('/oauth/userinfo', 200, { sub: 'u1', email: 'test@test.com', organizations: [] });
    server.post('/oauth/introspect', 200, { active: true, exp: Math.floor(Date.now() / 1000) + 3600 });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);
    await assert.rejects(() => p._subcommands['doctor']._handler(), /exit\(0\)/);
    assert.match(output, /fund\/admin/);
  });
});
