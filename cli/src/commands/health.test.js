import { describe, it, beforeEach, afterEach, mock } from 'node:test';
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

let output = '';

describe('health', () => {
  beforeEach(() => {
    output = '';
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
    fs.writeFileSync(CONFIG_FILE, JSON.stringify({ apiUrl: API }));
    mock.method(console, 'log', (...args) => { output += args.join(' ') + '\n'; });
    mock.method(console, 'error', () => {});
    mock.method(process, 'exit', (code) => {
      if (code !== 0) throw new Error(`exit(${code})`);
    });
  });

  afterEach(() => {
    nock.cleanAll();
    mock.restoreAll();
  });

  it('reports healthy status', async () => {
    nock(API).get('/api/public/health').reply(200, {
      status: 'ok', version: '1.0.0',
      checks: { database: 'ok', cache: 'ok' }
    });

    const mod = await import('./health.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['health']?._handler;
    assert.ok(handler);
    await handler();
    assert.match(output, /✅ OK/);
    assert.match(output, /database/);
    assert.match(output, /cache/);
  });

  it('reports unhealthy status', async () => {
    nock(API).get('/api/public/health').reply(200, {
      status: 'degraded',
      checks: { database: 'error', cache: 'ok' }
    });

    const mod = await import('./health.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['health']?._handler;
    await handler();
    assert.match(output, /error/);
  });

  it('handles connection refused', async () => {
    nock(API).get('/api/public/health').replyWithError({ code: 'ECONNREFUSED', message: 'refused' });

    const mod = await import('./health.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['health']?._handler;
    try { await handler(); } catch (e) { /* process.exit(1) */ }
    assert.match(output, /Cannot reach/);
  });

  it('handles HTTP 500', async () => {
    nock(API).get('/api/public/health').reply(500, { error: 'down' });

    const mod = await import('./health.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['health']?._handler;
    try { await handler(); } catch (e) { /* process.exit(1) */ }
    assert.match(output, /Error/);
  });
});
