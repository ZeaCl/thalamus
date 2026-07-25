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

describe('secret', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function S(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok', activeOrgId: 'org1' })); const m = await import('./secret.js'); const p = makeProgram(); m.register(p); return p; }

  it('list success', async () => { const API = await server.start(); server.get('/api/secrets', 200, { data: [{ id: 's1', name: 'k', provider: 'openai' }] }); const p = await S(API); await h(p, 'secret list')(); assert.match(output, /openai/); });
  it('list empty', async () => { const API = await server.start(); server.get('/api/secrets', 200, { data: [] }); const p = await S(API); await h(p, 'secret list')(); assert.match(output, /No secrets/); });
  it('list error', async () => { const API = await server.start(); server.get('/api/secrets', 500, {}); const p = await S(API); try { await h(p, 'secret list')(); } catch(e) {} assert.match(output, /Error|500/); });
  it('create success', async () => { const API = await server.start(); server.post('/api/secrets', 201, {}); const p = await S(API); await h(p, 'secret create')({ name: 'k', provider: 'openai', value: 'sk' }); assert.match(output, /created/); });
  it('create error', async () => { const API = await server.start(); server.post('/api/secrets', 400, { error: 'invalid' }); const p = await S(API); try { await h(p, 'secret create')({ name: 'k', provider: 'openai', value: 'sk' }); } catch(e) {} assert.match(output, /Error|invalid/); });
  it('delete success', async () => { const API = await server.start(); server.delete('/api/secrets/s1', 200, {}); const p = await S(API); await h(p, 'secret delete')('s1'); assert.match(output, /deleted/); });
  it('delete error', async () => { const API = await server.start(); server.delete('/api/secrets/s1', 500, {}); const p = await S(API); try { await h(p, 'secret delete')('s1'); } catch(e) {} assert.match(output, /Error|500/); });
  it('resolve success', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { sub: 'u1' }); server.get('/api/internal/secrets/resolve', 200, { value: 'sk-123' }); const p = await S(API); await h(p, 'secret resolve')({ provider: 'openai' }); assert.match(output, /sk-123/); });
  it('resolve not found', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { sub: 'u1' }); server.get('/api/internal/secrets/resolve', 404, { error: 'not found' }); const p = await S(API); try { await h(p, 'secret resolve')({ provider: 'x' }); } catch(e) {} assert.match(output, /not found|Error/); });
});
