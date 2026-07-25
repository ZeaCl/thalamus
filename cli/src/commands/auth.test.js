import { describe, it, after, before, mock } from 'node:test';
import assert from 'node:assert';
import nock from 'nock';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

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

describe('auth', () => {
  before(() => setupConfig());
  after(() => {
    nock.cleanAll();
    mock.restoreAll();
  });

  it('logout revokes token', async () => {
    nock(API).post('/oauth/revoke').reply(200, {});

    const mod = await import('./auth.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['logout']?._handler;
    assert.ok(handler);
    await handler();
  });

  it('set-token saves config', async () => {
    const mod = await import('./auth.js');
    const p = makeProgram();
    mod.register(p);

    const handler = p._subcommands['set-token']?._handler;
    assert.ok(handler);
    await handler('new-token-123', {});

    // Verify config was updated
    const saved = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
    assert.equal(saved.token, 'new-token-123');
  });
});
