import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import nock from 'nock';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

const API = 'http://test.localhost';
const CONFIG_FILE = path.join(os.homedir(), '.config', 'zea', 'config.json');

nock.disableNetConnect();
nock.enableNetConnect('127.0.0.1');

function setup() {
  fs.mkdirSync(path.dirname(CONFIG_FILE), { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API, token: 'tok', activeOrgId: 'org1' }));
  mock.method(console, 'log', () => {});
  mock.method(console, 'error', () => {});
  mock.method(process, 'exit', (c) => { if (c !== 0) throw new Error(`exit(${c})`); });
}

function handlerFor(prog, path) {
  const parts = path.split(' ');
  let cur = { _subcommands: prog._subcommands };
  for (const p of parts) {
    const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' '));
    if (!k) return null;
    cur = cur._subcommands[k];
  }
  return cur?._handler;
}

describe('user', () => {
  beforeEach(setup);
  afterEach(() => { nock.cleanAll(); mock.restoreAll(); });

  it('list users', async () => {
    nock(API).get('/api/users').reply(200, { data: [{ id: 'u1', email: 'a@b.com', status: 'active' }] });
    const mod = await import('./user.js'); const p = makeProgram(); mod.register(p);
    await handlerFor(p, 'user list')();
  });

  it('show user', async () => {
    nock(API).get('/api/users/u1').reply(200, { data: { id: 'u1', email: 'a@b.com', status: 'active' } });
    const mod = await import('./user.js'); const p = makeProgram(); mod.register(p);
    await handlerFor(p, 'user show')('u1');
  });

  it('create user', async () => {
    nock(API).post('/api/users').reply(201, { data: { id: 'u1', email: 'new@b.com' } });
    const mod = await import('./user.js'); const p = makeProgram(); mod.register(p);
    await handlerFor(p, 'user create')({ email: 'new@b.com', password: 'Pass123!' });
  });

  it('delete user', async () => {
    nock(API).delete('/api/users/u1').reply(200, {});
    const mod = await import('./user.js'); const p = makeProgram(); mod.register(p);
    await handlerFor(p, 'user delete')('u1');
  });

  it('user scopes', async () => {
    nock(API).get('/api/users/u1/effective-scopes').reply(200, { data: ['api:read'] });
    const mod = await import('./user.js'); const p = makeProgram(); mod.register(p);
    await handlerFor(p, 'user scopes')('u1');
  });
});
