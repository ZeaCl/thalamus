import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { makeProgram } from '../../test/helpers.js';

const CFG = path.join(os.homedir(), '.config', 'zea', 'config.json');
let output;
function h(prog, cmd) { const parts = cmd.split(' '); let cur = { _subcommands: prog._subcommands }; for (const p of parts) { const k = Object.keys(cur._subcommands).find(k => k === p || k.startsWith(p + ' ')); if (!k) return null; cur = cur._subcommands[k]; } return cur?._handler; }

describe('config', () => {
  beforeEach(async () => { output = ''; fs.mkdirSync(path.dirname(CFG), { recursive: true }); fs.writeFileSync(CFG, JSON.stringify({ apiUrl: 'http://test' })); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(() => { mock.restoreAll(); });
  async function setup() { const m = await import('./config.js'); const p = makeProgram(); m.register(p); return p; }

  it('list', async () => { const p = await setup(); await h(p, 'config list')(); assert.match(output, /apiUrl/); });
  it('get', async () => { const p = await setup(); await h(p, 'config get')('apiUrl'); assert.match(output, /http:\/\/test/); });
  it('set', async () => { const p = await setup(); await h(p, 'config set')('apiUrl', 'http://new'); assert.match(output, /saved/); });
  it('set-env', async () => { const p = await setup(); await h(p, 'config set-env')('local'); assert.match(output, /local/); });
  it('path', async () => { const p = await setup(); await h(p, 'config path')(); assert.match(output, /config/); });
});
