import zeaFetch from '../lib/http.js';
import { getClient } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const internalCmd = program.command('internal').description('Internal microservice operations');

  internalCmd.command('agent-token')
    .description('Create an agent token (Cerebelum integration)')
    .requiredOption('--task-id <id>', 'Task identifier')
    .requiredOption('--agent-id <id>', 'Agent identifier')
    .option('--scopes <scopes>', 'Space-separated scopes')
    .action(async (options) => {
      const opts = getGlobalOpts();
      try {
        if (opts.dryRun) {
          console.log('⚠️  DRY RUN — would POST /api/internal/agent-token');
          return;
        }
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/internal/agent-token`, {
          method: 'POST', headers: client.headers,
          body: JSON.stringify({
            task_id: options.taskId,
            agent_id: options.agentId,
            scopes: options.scopes || 'openid',
          })
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        console.log(`✅ Agent token created.`);
        if (data.token) console.log(`   Token: ${data.token}`);
      } catch (e) { handleError(e); process.exit(1); }
    });

  internalCmd.command('agent-config <user_id>')
    .description('Show agent configuration for a user')
    .action(async (userId) => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/internal/users/${userId}/agent-config`, {
          headers: client.headers
        });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const data = await resp.json();
        if (opts.output === 'json') { console.log(JSON.stringify(data, null, 2)); return; }
        console.log('Agent Config:');
        console.log(JSON.stringify(data, null, 2));
      } catch (e) { handleError(e); process.exit(1); }
    });
}
