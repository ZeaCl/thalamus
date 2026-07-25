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

describe('admin', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function S(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok' })); const m = await import('./admin.js'); const p = makeProgram(); m.register(p); return p; }

  it('list success', async () => { const API = await server.start(); server.get('/api/admin/api-keys', 200, { data: [{ id: 'k1', name: 'K1', is_active: true, scopes: ['x'] }] }); const p = await S(API); await h(p, 'admin api-key list')(); assert.match(output, /K1/); });
  it('list forbidden', async () => { const API = await server.start(); server.get('/api/admin/api-keys', 403, { error: 'forbidden' }); const p = await S(API); try { await h(p, 'admin api-key list')(); } catch(e) {} assert.match(output, /Forbidden/); });
  it('show success', async () => { const API = await server.start(); server.get('/api/admin/api-keys/k1', 200, { data: { id: 'k1', name: 'K1', is_active: true, scopes: ['x'] } }); const p = await S(API); await h(p, 'admin api-key show')('k1'); assert.match(output, /K1/); });
  it('create success', async () => { const API = await server.start(); server.post('/api/admin/api-keys', 201, { data: { id: 'k1', api_key: 'ak-123', name: 'K' } }); const p = await S(API); await h(p, 'admin api-key create')({ name: 'K', scopes: 'x' }); assert.match(output, /created/); });
  it('create forbidden', async () => { const API = await server.start(); server.post('/api/admin/api-keys', 403, { error: 'forbidden' }); const p = await S(API); try { await h(p, 'admin api-key create')({ name: 'K' }); } catch(e) {} assert.match(output, /Forbidden/); });
  it('revoke success', async () => { const API = await server.start(); server.delete('/api/admin/api-keys/k1', 200, {}); const p = await S(API); await h(p, 'admin api-key revoke')('k1'); assert.match(output, /revoked/); });
  it('rotate success', async () => { const API = await server.start(); server.post('/api/admin/api-keys/k1/rotate', 200, { data: { api_key: 'new' } }); const p = await S(API); await h(p, 'admin api-key rotate')('k1'); });
});
