import { describe, it, after, before, mock } from 'node:test';
import assert from 'node:assert';
import nock from 'nock';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

/**
 * Behavioral tests for account commands — nock + temp config file.
 */

const API = 'http://test.localhost';
const CONFIG_DIR = path.join(os.homedir(), '.config', 'zea');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

mock.method(process, 'exit', (code) => {
  if (code !== 0) throw new Error(`exit(${code})`);
});

nock.disableNetConnect();
nock.enableNetConnect('127.0.0.1');

function setupConfig(token = 'tok') {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API, token, activeOrgId: 'org1' }));
}

function handlerFor(program, path) {
  const parts = path.split(' ');
  let cur = { _subcommands: program._subcommands };
  for (const p of parts) {
    const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' '));
    if (!k) return null;
    cur = cur._subcommands[k];
  }
  return cur?._handler;
}

describe('account', () => {
  before(() => setupConfig());
  after(() => {
    nock.cleanAll();
    mock.restoreAll();
  });

  it('register', async () => {
    nock(API).post('/api/public/register').reply(201, { data: { id: 'u1' } });

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'register')({ email: 'test@test.com', password: 'Pass123!' });
  });

  it('register handles 409', async () => {
    nock(API).post('/api/public/register').reply(409, { error: 'dup' });

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await assert.rejects(() =>
      handlerFor(p, 'register')({ email: 'dup@test.com', password: 'Pass123!' })
    );
  });

  it('verify-email', async () => {
    nock(API).post('/api/public/verify-email').reply(200, { message: 'ok' });

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'verify-email')({ token: 'abc' });
  });

  it('resend-verification', async () => {
    nock(API).post('/api/public/resend-verification').reply(200, {});

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'resend-verification')({ email: 't@t.com' });
  });

  it('password reset', async () => {
    nock(API).post('/api/public/password/reset').reply(200, {});

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'password reset')({ email: 't@t.com' });
  });

  it('password confirm-reset', async () => {
    nock(API).post('/api/public/password/confirm-reset').reply(200, {});

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'password confirm-reset')({ token: 'abc', password: 'new' });
  });

  it('password change', async () => {
    nock(API).put('/api/password/change').reply(200, {});

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'password change')({ current: 'old', new: 'new' });
  });

  it('avatar delete', async () => {
    nock(API).delete('/api/avatar').reply(200, {});

    const mod = await import('./account.js');
    const p = makeProgram();
    mod.register(p);
    await handlerFor(p, 'avatar delete')();
  });
});
