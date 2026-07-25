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

const CD = { id: 'c1', name: 'App', client_type: 'confidential', redirect_uris: ['http://cb'], grant_types: ['authorization_code'], scopes: ['openid'], is_active: true, trusted: false };

describe('client', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function S(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok', activeOrgId: 'org1' })); const m = await import('./client.js'); const p = makeProgram(); m.register(p); return p; }

  it('list success', async () => { const API = await server.start(); server.get('/api/clients', 200, { data: [CD] }); const p = await S(API); await h(p, 'client list')(); assert.match(output, /App/); });
  it('list error', async () => { const API = await server.start(); server.get('/api/clients', 500, {}); const p = await S(API); try { await h(p, 'client list')(); } catch(e) {} assert.match(output, /Error|500/); });
  it('show success', async () => { const API = await server.start(); server.get('/api/clients/c1', 200, { data: CD }); const p = await S(API); await h(p, 'client show')('c1'); assert.match(output, /App/); });
  it('show not found', async () => { const API = await server.start(); server.get('/api/clients/x', 404, { error: 'not found' }); const p = await S(API); try { await h(p, 'client show')('x'); } catch(e) {} assert.match(output, /not found/); });
  it('create success', async () => { const API = await server.start(); server.post('/api/clients', 201, { data: { id: 'c1', name: 'New', client_type: 'confidential' }, message: 'created' }); const p = await S(API); await h(p, 'client create')({ name: 'New' }); assert.match(output, /created/); });
  it('create error', async () => { const API = await server.start(); server.post('/api/clients', 400, { error: 'invalid' }); const p = await S(API); try { await h(p, 'client create')({ name: 'New' }); } catch(e) {} assert.match(output, /invalid|Error/); });
  it('update success', async () => { const API = await server.start(); server.patch('/api/clients/c1', 200, { data: { ...CD, name: 'Updated' } }); const p = await S(API); await h(p, 'client update')('c1', { name: 'Updated' }); assert.match(output, /updated/); });
  it('update no opts', async () => { const API = await server.start(); const p = await S(API); try { await h(p, 'client update')('c1', {}); } catch(e) {} assert.match(output, /Nothing to update/); });
  it('delete success', async () => { const API = await server.start(); server.delete('/api/clients/c1', 200, {}); const p = await S(API); await h(p, 'client delete')('c1'); assert.match(output, /deactivated/); });
  it('delete error', async () => { const API = await server.start(); server.delete('/api/clients/c1', 404, { error: 'not found' }); const p = await S(API); try { await h(p, 'client delete')('c1'); } catch(e) {} assert.match(output, /not found|Error/); });
  it('rotate-secret success', async () => { const API = await server.start(); server.post('/api/clients/c1/rotate-secret', 200, { data: { client_secret: 'newsec' }, message: 'rotated' }); const p = await S(API); await h(p, 'client rotate-secret')('c1'); });
  it('rotate-secret error', async () => { const API = await server.start(); server.post('/api/clients/c1/rotate-secret', 400, { error: 'public client' }); const p = await S(API); try { await h(p, 'client rotate-secret')('c1'); } catch(e) {} });
  it('trust on', async () => { const API = await server.start(); server.patch('/api/clients/c1/trust', 200, { data: { ...CD, trusted: true } }); const p = await S(API); await h(p, 'client trust')('c1', { on: true }); assert.match(output, /trusted/); });
  it('trust error', async () => { const API = await server.start(); server.patch('/api/clients/c1/trust', 500, { error: 'fail' }); const p = await S(API); try { await h(p, 'client trust')('c1', { on: true }); } catch(e) {} });
  it('validate success', async () => { const API = await server.start(); server.get('/api/clients/c1/validate', 200, { client_name: 'App', status: 'pass', summary: { pass: 3, warn: 0, fail: 0 }, checks: [] }); const p = await S(API); await h(p, 'client validate')('c1'); assert.match(output, /pass/); });
  it('validate fail', async () => { const API = await server.start(); server.get('/api/clients/c1/validate', 200, { client_name: 'App', status: 'invalid', summary: { pass: 1, warn: 0, fail: 2 }, checks: [{ name: 'c', status: 'fail', message: 'bad' }] }); const p = await S(API); try { await h(p, 'client validate')('c1'); } catch(e) {} assert.match(output, /bad/); });
  it('add-redirect-uri', async () => { const API = await server.start(); server.post('/api/clients/c1/add-redirect-uri', 200, {}); const p = await S(API); await h(p, 'client add-redirect-uri')('c1', { uri: 'http://new/cb' }); assert.match(output, /added/); });
});
