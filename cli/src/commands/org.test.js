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

const ORG = { data: { id: 'org1', name: 'ZEA', plan_type: 'standard', status: 'active', verified: true, current_user_count: 2, max_users: 10 } };

describe('org', () => {
  beforeEach(async () => { output = ''; server = createTestServer(); fs.mkdirSync(path.dirname(CFG), { recursive: true }); mock.method(console, 'log', (...a) => { output += a.join(' ') + '\n'; }); mock.method(console, 'error', () => {}); });
  afterEach(async () => { await server.stop(); mock.restoreAll(); });
  async function S(apiUrl) { fs.writeFileSync(CFG, JSON.stringify({ apiUrl, token: 'tok', activeOrgId: 'org1' })); const m = await import('./org.js'); const p = makeProgram(); m.register(p); return p; }

  it('list success', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); const p = await S(API); await h(p, 'org list')(); assert.match(output, /ZEA/); });
  it('list error', async () => { const API = await server.start(); server.get('/oauth/userinfo', 500, {}); const p = await S(API); try { await h(p, 'org list')(); } catch(e) {} assert.match(output, /Error|HTTP/); });
  it('show success', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.get('/api/organizations/org1', 200, ORG); const p = await S(API); await h(p, 'org show')('org1'); assert.match(output, /ZEA/); });
  it('show not found', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [] }); const p = await S(API); try { await h(p, 'org show')('x'); } catch(e) {} assert.match(output, /not found/); });
  it('create success', async () => { const API = await server.start(); server.post('/api/organizations', 201, { data: { id: 'org1', name: 'NewOrg' } }); const p = await S(API); await h(p, 'org create')({ name: 'NewOrg', email: 'o@t.com' }); assert.match(output, /created/); });
  it('create error', async () => { const API = await server.start(); server.post('/api/organizations', 400, { error: 'bad' }); const p = await S(API); try { await h(p, 'org create')({ name: 'N', email: 'o' }); } catch(e) {} assert.match(output, /Error|bad/); });
  it('update success', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.patch('/api/organizations/org1', 200, {}); const p = await S(API); await h(p, 'org update')('org1', { name: 'New' }); assert.match(output, /updated/); });
  it('delete success', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.delete('/api/organizations/org1', 200, {}); const p = await S(API); await h(p, 'org delete')('org1'); assert.match(output, /deleted/); });
  it('members list', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.get('/api/organizations/org1', 200, { data: { members: [{ user_id: 'u1', email: 'a@b.com', role: 'admin' }] } }); const p = await S(API); await h(p, 'org member list')('zea'); assert.match(output, /a@b.com/); });
  it('member add', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.post('/api/organizations/org1/members', 200, {}); const p = await S(API); await h(p, 'org member add')('zea', { email: 'a@b.com', role: 'admin' }); assert.match(output, /added/); });
  it('member remove', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.delete('/api/organizations/org1/members/u1', 200, {}); const p = await S(API); await h(p, 'org member remove')('zea', { userId: 'u1' }); assert.match(output, /removed/); });
  it('saml show', async () => { const API = await server.start(); server.get('/oauth/userinfo', 200, { organizations: [{ id: 'org1', name: 'ZEA', slug: 'zea' }] }); server.get('/api/organizations/org1/saml-config', 200, { data: { name: 'SAML', idp_entity_id: 'idp', idp_sso_url: 'http://sso', enabled: true, jit_provisioning: false } }); const p = await S(API); await h(p, 'org saml show')('zea'); assert.match(output, /SAML/); });
});
