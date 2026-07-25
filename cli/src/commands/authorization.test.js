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

describe('authorization', () => {
  beforeEach(setup); afterEach(() => { nock.cleanAll(); mock.restoreAll(); });
  it('validate-step', async () => {
    nock(API).post('/api/authorization/validate-step').reply(200, { allowed: true });
    const m = await import('./authorization.js'); const p = makeProgram(); m.register(p);
    await h(p, 'authorization validate-step')({ stepId: 's1', agentToken: 'tok' });
  });
});
