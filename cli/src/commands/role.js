import zeaFetch from '../lib/http.js';
import { getClient } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const roleCmd = program.command('role').description('Role management');

  roleCmd.command('list')
    .description('List roles')
    .action(async () => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/roles`, { headers: client.headers });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const result = await resp.json();
        const roles = result.data || [];
        if (opts.output === 'json') { console.log(JSON.stringify(roles, null, 2)); return; }
        if (roles.length === 0) { console.log('No roles.'); return; }
        for (const r of roles) console.log(`   ${r.name} (${r.id}) — scopes: ${(r.scopes || []).join(', ')}`);
      } catch (e) { handleError(e); process.exit(1); }
    });

  roleCmd.command('show <id>')
    .description('Show role details')
    .action(async (id) => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/roles/${id}`, { headers: client.headers });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const r = (await resp.json()).data;
        if (opts.output === 'json') { console.log(JSON.stringify(r, null, 2)); return; }
        console.log(`   Name:   ${r.name}`);
        console.log(`   ID:     ${r.id}`);
        console.log(`   Scopes: ${(r.scopes || []).join(', ') || '(none)'}`);
      } catch (e) { handleError(e); process.exit(1); }
    });

  roleCmd.command('create')
    .description('Create a new role')
    .requiredOption('--name <name>', 'Role name')
    .requiredOption('--scopes <scopes>', 'Comma-separated scopes')
    .action(async (options) => {
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/roles`, {
          method: 'POST', headers: client.headers,
          body: JSON.stringify({
            name: options.name,
            scopes: options.scopes.split(',').map(s => s.trim()).filter(Boolean),
          })
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const r = (await resp.json()).data;
        console.log(`✅ Role created: ${r.name} (${r.id})`);
      } catch (e) { handleError(e); process.exit(1); }
    });

  roleCmd.command('update <id>')
    .description('Update a role')
    .option('--name <name>', 'New name')
    .option('--scopes <scopes>', 'Comma-separated scopes')
    .action(async (id, options) => {
      try {
        const body = {};
        if (options.name) body.name = options.name;
        if (options.scopes) body.scopes = options.scopes.split(',').map(s => s.trim()).filter(Boolean);
        if (Object.keys(body).length === 0) { console.error('❌ Nothing to update.'); process.exit(1); }
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/roles/${id}`, {
          method: 'PATCH', headers: client.headers, body: JSON.stringify(body)
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        console.log('✅ Role updated.');
      } catch (e) { handleError(e); process.exit(1); }
    });

  roleCmd.command('delete <id>')
    .description('Delete a role')
    .action(async (id) => {
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/roles/${id}`, {
          method: 'DELETE', headers: client.headers
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        console.log('✅ Role deleted.');
      } catch (e) { handleError(e); process.exit(1); }
    });
}
