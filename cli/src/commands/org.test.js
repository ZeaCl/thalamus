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

const orgData = { data: { id: 'org1', name: 'TestOrg', plan_type: 'standard', status: 'active', verified: true, current_user_count: 2, max_users: 10 } };

describe('org', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function setup(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok', activeOrgId: 'org1' })); const m = await import('./org.js'); const p = makeProgram(); m.register(p); return p; }

  it('list', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); const p = await setup(API); await h(p, 'org list')(); assert.match(output, /ZEA/); });
  it('show', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.get('/api/organizations/org1', 200, orgData); const p = await setup(API); await h(p, 'org show')('org1'); assert.match(output, /TestOrg/); });
  it('create', async () => { const API = await server.start(); server.post('/api/organizations', 201, { data: { id: 'org1', name: 'NewOrg', plan_type: 'standard' } }); const p = await setup(API); await h(p, 'org create')({ name: 'NewOrg', email: 'o@t.com', plan: 'standard' }); assert.match(output, /created/); });
  it('members list', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.get('/api/organizations/org1', 200, { data: { members: [{ user_id: 'u1', email: 'a@b.com', role: 'admin' }] } }); const p = await setup(API); await h(p, 'org member list')('zea'); assert.match(output, /a@b.com/); });
});
