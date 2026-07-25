import { describe, it, after, beforeEach, mock } from 'node:test';
import assert from 'node:assert';
import nock from 'nock';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

const API = 'http://test.localhost';
const CONFIG_DIR = path.join(os.homedir(), '.config', 'zea');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

nock.disableNetConnect();
nock.enableNetConnect('127.0.0.1');

function fakeJwt(payload = { sub: 'u1', email: 'test@test.com' }) {
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  return `${b64({ alg: 'RS256' })}.${b64(payload)}.sig`;
}

let output = '';

describe('doctor', () => {
  beforeEach(() => {
    output = '';
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
    mock.method(console, 'log', (...args) => { output += args.join(' ') + '\n'; });
    mock.method(console, 'error', () => {});
    mock.method(process, 'exit', (code) => {
      throw new Error(`exit(${code})`);
    });
  });

  afterEach(() => {
    nock.cleanAll();
    mock.restoreAll();
  });

  it('all checks pass', async () => {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({
      apiUrl: API, token: fakeJwt(), activeOrgId: 'org1'
    }));

    nock(API).get('/api/public/health').reply(200, {
      status: 'ok', version: '1.0.0', checks: { database: 'ok', cache: 'ok' }
    });
    nock(API).get('/oauth/userinfo').reply(200, {
      sub: 'u1', email: 'test@test.com',
      organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }],
      organization: { name: 'ZEA' }
    });
    nock(API).post('/oauth/introspect').reply(200, {
      active: true, exp: Math.floor(Date.now() / 1000) + 3600
    });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['doctor']?._handler;
    assert.ok(handler);
    await assert.rejects(() => handler(), /exit\(0\)/);
    assert.match(output, /reachable/);
    assert.match(output, /test@test\.com/);
    assert.match(output, /ZEA/);
  });

  it('unreachable server', async () => {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API }));

    nock(API).get('/api/public/health').replyWithError({ code: 'ECONNREFUSED', message: 'refused' });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['doctor']?._handler;
    try { await handler(); } catch (e) { /* exit mock */ }
    assert.match(output, /Cannot reach/);
  });

  it('no token warning', async () => {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API }));

    nock(API).get('/api/public/health').reply(200, { status: 'ok' });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['doctor']?._handler;
    try { await handler(); } catch (e) { /* exit mock */ }
    assert.match(output, /No token/);
  });

  it('domain roles from JWT', async () => {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({
      apiUrl: API,
      token: fakeJwt({
        sub: 'u1', email: 'test@test.com',
        domain_roles: [{ domain: 'fund', role: 'admin', org_id: 'org12345', scopes: ['read'] }]
      }),
      activeOrgId: 'org1'
    }));

    nock(API).get('/api/public/health').reply(200, { status: 'ok' });
    nock(API).get('/oauth/userinfo').reply(200, {
      sub: 'u1', email: 'test@test.com', organizations: []
    });
    nock(API).post('/oauth/introspect').reply(200, {
      active: true, exp: Math.floor(Date.now() / 1000) + 3600
    });

    const mod = await import('./doctor.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['doctor']?._handler;
    await assert.rejects(() => handler(), /exit\(0\)/);
    assert.match(output, /fund\/admin/);
  });
});
