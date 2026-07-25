import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';
import { createTestServer } from '../../test/test-server.js';

const CFG = path.join(os.homedir(), '.config', 'zea', 'config.json');
let server, output;

function h(prog, path) {
  const parts = path.split(' '); let cur = { _subcommands: prog._subcommands };
  for (const p of parts) { const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' ')); if (!k) return null; cur = cur._subcommands[k]; }
  return cur?._handler;
}

mock.method(process, 'exit', (c) => { if (c !== 0) throw new Error(`exit(${c})`); });

describe('role', () => {
  beforeEach(async () => {
    output = '';
    server = createTestServer();
    fs.mkdirSync(path.dirname(CFG), { recursive: true });
    fs.writeFileSync(CFG, JSON.stringify({ apiUrl: 'http://127.0.0.1:99999', token: 'tok' }));
    mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; });
    mock.method(console, 'error', () => {});
  });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });

  async function setup(apiUrl) {
    fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok' }));
    const m = await import('./role.js');
    const p = makeProgram();
    m.register(p);
    return p;
  }

  it('list success', async () => {
    const API = await server.start();
    server.get('/api/roles', 200, { data: [{ id: 'r1', name: 'Admin', scopes: ['api:read'] }] });
    const p = await setup(API);
    await h(p, 'role list')();
    assert.match(output, /Admin/);
  });

  it('list empty', async () => {
    const API = await server.start();
    server.get('/api/roles', 200, { data: [] });
    const p = await setup(API);
    await h(p, 'role list')();
    assert.match(output, /No roles/);
  });

  it('create success', async () => {
    const API = await server.start();
    server.post('/api/roles', 201, { data: { id: 'r1', name: 'Test' } });
    const p = await setup(API);
    await h(p, 'role create')({ name: 'Test', scopes: 'api:read,api:write' });
    assert.match(output, /created/);
  });

  it('create error', async () => {
    const API = await server.start();
    server.post('/api/roles', 400, { error: 'invalid' });
    const p = await setup(API);
    try { await h(p, 'role create')({ name: 'Test', scopes: 'x' }); } catch (e) { /* exit */ }
    assert.match(output, /Error|invalid/);
  });

  it('show success', async () => {
    const API = await server.start();
    server.get('/api/roles/r1', 200, { data: { id: 'r1', name: 'Admin', scopes: ['api:read'] } });
    const p = await setup(API);
    await h(p, 'role show')('r1');
    assert.match(output, /Admin/);
  });

  it('show not found', async () => {
    const API = await server.start();
    server.get('/api/roles/x', 404, { error: 'not found' });
    const p = await setup(API);
    try { await h(p, 'role show')('x'); } catch (e) { /* exit */ }
    assert.match(output, /not found|Error/);
  });

  it('delete success', async () => {
    const API = await server.start();
    server.delete('/api/roles/r1', 200, {});
    const p = await setup(API);
    await h(p, 'role delete')('r1');
    assert.match(output, /deleted/);
  });

  it('delete error', async () => {
    const API = await server.start();
    server.delete('/api/roles/r1', 500, { error: 'server error' });
    const p = await setup(API);
    try { await h(p, 'role delete')('r1'); } catch (e) { /* exit */ }
    assert.match(output, /Error|server error/);
  });
});
