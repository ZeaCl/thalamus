import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';
import { createTestServer } from '../../test/test-server.js';

const CFG = path.join(os.homedir(), '.config', 'zea', 'config.json');
let server, output;

function h(prog, cmd) {
  const parts = cmd.split(' '); let cur = { _subcommands: prog._subcommands };
  for (const p of parts) { const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' ')); if (!k) return null; cur = cur._subcommands[k]; }
  return cur?._handler;
}
mock.method(process, 'exit', (c) => { if (c !== 0) throw new Error(`exit(${c})`); });

describe('client', () => {
  beforeEach(async () => {
    output = ''; server = createTestServer();
    fs.mkdirSync(path.dirname(CFG), { recursive: true });
    mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; });
    mock.method(console, 'error', () => {});
  });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });

  async function setup(apiUrl) {
    fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok', activeOrgId: 'org1' }));
    const m = await import('./client.js'); const p = makeProgram(); m.register(p); return p;
  }

  const clientData = { id: 'client_c1', name: 'MyApp', client_type: 'confidential', redirect_uris: ['http://localhost/cb'], grant_types: ['authorization_code'], scopes: ['openid'], is_active: true, trusted: false };

  it('list', async () => { const API = await server.start(); server.get('/api/clients', 200, { data: [clientData] }); const p = await setup(API); await h(p, 'client list')(); assert.match(output, /MyApp/); });
  it('list error', async () => { const API = await server.start(); server.get('/api/clients', 500, {}); const p = await setup(API); try { await h(p, 'client list')(); } catch(e) {} assert.match(output, /Error|500/); });
  it('show', async () => { const API = await server.start(); server.get('/api/clients/c1', 200, { data: clientData }); const p = await setup(API); await h(p, 'client show')('c1'); assert.match(output, /MyApp/); });
  it('show not found', async () => { const API = await server.start(); server.get('/api/clients/x', 404, { error: 'not found' }); const p = await setup(API); try { await h(p, 'client show')('x'); } catch(e) {} assert.match(output, /not found/); });
  it('create', async () => { const API = await server.start(); server.post('/api/clients', 201, { data: { id: 'c1', name: 'New', client_type: 'confidential', client_secret: 'sec' }, message: 'created' }); const p = await setup(API); await h(p, 'client create')({ name: 'New' }); assert.match(output, /created/); });
  it('delete', async () => { const API = await server.start(); server.delete('/api/clients/c1', 200, {}); const p = await setup(API); await h(p, 'client delete')('c1'); assert.match(output, /deactivated/); });
  it('trust', async () => { const API = await server.start(); server.patch('/api/clients/c1/trust', 200, { data: { id: 'c1', trusted: true } }); const p = await setup(API); await h(p, 'client trust')('c1', { on: true }); assert.match(output, /trusted/); });
  it('validate', async () => { const API = await server.start(); server.get('/api/clients/c1/validate', 200, { client_name: 'App', status: 'pass', summary: { pass: 3, warn: 0, fail: 0 }, checks: [] }); const p = await setup(API); await h(p, 'client validate')('c1'); assert.match(output, /pass/); });
});
