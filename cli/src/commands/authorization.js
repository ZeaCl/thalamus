import zeaFetch from '../lib/http.js';
import { getClient } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  program.command('authorization')
    .description('Authorization operations')
    .command('validate-step')
    .description('Validate an agent workflow step (Cerebelum integration)')
    .requiredOption('--step-id <id>', 'Step identifier')
    .requiredOption('--agent-token <token>', 'Agent bearer token')
    .action(async (options) => {
      const opts = getGlobalOpts();
      try {
        if (opts.dryRun) {
          console.log('⚠️  DRY RUN — would POST /api/authorization/validate-step');
          return;
        }
        const client = await getClient();
        const resp = await zeaFetch(`${client.apiUrl}/api/authorization/validate-step`, {
          method: 'POST', headers: {
            ...client.headers,
            Authorization: `Bearer ${options.agentToken}`,
          },
          body: JSON.stringify({ step_id: options.stepId })
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP ${resp.status}`);
        }
        const data = await resp.json();
        console.log('✅ Step authorized.');
        if (data.allowed !== undefined) console.log(`   Allowed: ${data.allowed}`);
      } catch (e) { handleError(e); process.exit(1); }
    });
}
