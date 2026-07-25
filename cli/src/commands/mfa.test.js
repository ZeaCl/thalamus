import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import nock from 'nock';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

const API = 'http://test.localhost';
const CFG = path.join(os.homedir(), '.config', 'zea', 'config.json');
nock.disableNetConnect(); nock.enableNetConnect('127.0.0.1');

function h(prog, path) {
  const parts = path.split(' '); let cur = { _subcommands: prog._subcommands };
  for (const p of parts) { const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' ')); if (!k) return null; cur = cur._subcommands[k]; }
  return cur?._handler;
}
function setup() {
  fs.mkdirSync(path.dirname(CFG), { recursive: true });
  fs.writeFileSync(CFG, JSON.stringify({ apiUrl: API, token: 'tok' }));
  mock.method(console, 'log', () => {}); mock.method(console, 'error', () => {});
  mock.method(process, 'exit', (c) => { if (c !== 0) throw new Error(`exit(${c})`); });
}

describe('mfa', () => {
  beforeEach(setup); afterEach(() => { nock.cleanAll(); mock.restoreAll(); });

  it('setup', async () => { nock(API).post('/api/mfa/totp/setup').reply(200, { secret: 'S', otpauth_uri: 'u' }); const m = await import('./mfa.js'); const p = makeProgram(); m.register(p); await h(p, 'mfa setup')(); });
  it('verify', async () => { nock(API).post('/api/mfa/totp/verify').reply(200, { backup_codes: ['a'] }); const m = await import('./mfa.js'); const p = makeProgram(); m.register(p); await h(p, 'mfa verify')({ code: '123456' }); });
  it('verify-code', async () => { nock(API).post('/api/mfa/verify').reply(200, {}); const m = await import('./mfa.js'); const p = makeProgram(); m.register(p); await h(p, 'mfa verify-code')({ code: '123456' }); });
  it('disable', async () => { nock(API).delete('/api/mfa/disable').reply(200, {}); const m = await import('./mfa.js'); const p = makeProgram(); m.register(p); await h(p, 'mfa disable')(); });
});
