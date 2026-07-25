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

describe('domain', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function S(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok' })); const m = await import('./domain.js'); const p = makeProgram(); m.register(p); return p; }

  it('list success', async () => { const API = await server.start(); server.get('/api/domains', 200, { data: [{ domain: 'fund', scopes: [{ scope: 'read', description: 'Read' }] }] }); const p = await S(API); await h(p, 'domain list')(); assert.match(output, /fund/); });
  it('list empty', async () => { const API = await server.start(); server.get('/api/domains', 200, { data: [] }); const p = await S(API); await h(p, 'domain list')(); assert.match(output, /No domains/); });
  it('list error', async () => { const API = await server.start(); server.get('/api/domains', 500, {}); const p = await S(API); try { await h(p, 'domain list')(); } catch(e) {} assert.match(output, /Error|500/); });
  it('register success', async () => { const API = await server.start(); server.post('/api/domains/register', 200, { domain: 'v', scope_count: 2 }); const p = await S(API); await h(p, 'domain register')({ domain: 'v', scopes: '[{"scope":"read","description":"Read"}]' }); assert.match(output, /registered/); });
  it('register invalid JSON', async () => { const API = await server.start(); const p = await S(API); try { await h(p, 'domain register')({ domain: 'v', scopes: 'bad' }); } catch(e) {} assert.match(output, /Invalid JSON/); });
  it('grant success', async () => { const API = await server.start(); server.post('/api/domains/roles/grant', 200, { message: 'granted' }); const p = await S(API); await h(p, 'domain grant')({ user: 'u1', org: 'o1', domain: 'd', role: 'r', scopes: 'read' }); assert.match(output, /granted/); });
  it('revoke success', async () => { const API = await server.start(); server.delete('/api/domains/roles/revoke', 200, { message: 'revoked' }); const p = await S(API); await h(p, 'domain revoke')({ user: 'u1', org: 'o1', domain: 'd', role: 'r' }); assert.match(output, /revoked/); });
  it('roles success', async () => { const API = await server.start(); server.get('/api/domains/roles', 200, { data: [{ domain: 'd', role: 'r', user_id: 'u1', scopes: ['read'] }] }); const p = await S(API); await h(p, 'domain roles')(); assert.match(output, /d\/r/); });
});
