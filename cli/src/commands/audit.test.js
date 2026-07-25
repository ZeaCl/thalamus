import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';
import { createTestServer } from '../../test/test-server.js';

const CFG = path.join(os.homedir(), '.config', 'zea', 'config.json');
let server, output;
function h(prog, cmd) { const parts = cmd.split(' '); let cur = { _subcommands: prog._subcommands }; for (const p of parts) { const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' ')); if (!k) return null; cur = cur._subcommands[k]; } return cur?._handler; }
mock.method(process, 'exit', (c) => { if (c !== 0) throw new Error(`exit(${c})`); });

describe('audit', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function setup(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok' })); const m = await import('./audit.js'); const p = makeProgram(); m.register(p); return p; }

  it('export', async () => { const API = await server.start(); server.get('/api/audit-logs/export', 200, { audit_logs: [{ timestamp: '2026-01-01', event_type: 'login', user: { email: 'a@b.com' } }], total_records: 1 }); const p = await setup(API); await h(p, 'audit export')(); assert.match(output, /login/); });
  it('oidc discovery', async () => { const API = await server.start(); server.get('/.well-known/openid-configuration', 200, { issuer: 'http://iss' }); const p = await setup(API); await h(p, 'oidc discovery')(); assert.match(output, /http:\/\/iss/); });
  it('oidc jwks', async () => { const API = await server.start(); server.get('/.well-known/jwks.json', 200, { keys: [{ kid: 'k1', alg: 'RS256', kty: 'RSA' }] }); const p = await setup(API); await h(p, 'oidc jwks')(); assert.match(output, /RS256/); });
});
