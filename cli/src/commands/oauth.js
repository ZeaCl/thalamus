import zeaFetch from '../lib/http.js';
import { loadConfig } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const oauthCmd = program.command('oauth').description('OAuth2 operations');

  oauthCmd.command('agent-token')
    .description('Create an agent-scoped OAuth2 token (task-scoped, delegation-aware)')
    .requiredOption('--client-id <id>', 'OAuth2 client identifier')
    .requiredOption('--client-secret <secret>', 'OAuth2 client secret')
    .requiredOption('--organization-id <id>', 'Organization UUID')
    .requiredOption('--delegator-user-id <id>', 'User ID of human authorizer')
    .requiredOption('--agent-type <type>', 'autonomous | supervisor | tool')
    .requiredOption('--task-description <desc>', 'Human-readable task description')
    .requiredOption('--scope <scopes>', 'Space-separated scopes (must be subset of client allowed_scopes)')
    .option('--task-id <id>', 'External task identifier (UUID)')
    .option('--parent-agent-id <id>', 'Parent agent token ID for delegation chains')
    .option('--expires-in <seconds>', 'Custom TTL in seconds (max 3600)')
    .option('--reason <reason>', 'Human-readable reason/intent for audit trail')
    .action(async (options) => {
      const validAgentTypes = ['autonomous', 'supervisor', 'tool'];
      if (!validAgentTypes.includes(options.agentType)) {
        console.error(`❌ Invalid agent type: ${options.agentType}. Must be: ${validAgentTypes.join(', ')}`);
        process.exit(1);
      }

      const opts = getGlobalOpts();
      try {
        const config = await loadConfig();
        const apiUrl = process.env.ZEA_API_URL || process.env.THALAMUS_API_URL || config.apiUrl || 'https://auth.zea.cl';

        const body = {
          client_id: options.clientId,
          client_secret: options.clientSecret,
          organization_id: options.organizationId,
          delegator_user_id: options.delegatorUserId,
          agent_type: options.agentType,
          task_description: options.taskDescription,
          scope: options.scope
        };

        if (options.taskId) body.task_id = options.taskId;
        if (options.parentAgentId) body.parent_agent_id = options.parentAgentId;
        if (options.expiresIn) body.expires_in = options.expiresIn;
        if (options.reason) body.reason = options.reason;

        if (opts.dryRun) {
          console.log('⚠️  DRY RUN — would execute:');
          console.log(`   POST ${apiUrl}/oauth/agent-token`);
          console.log(`   Body: ${JSON.stringify(body, null, 2)}`);
          return;
        }

        const response = await zeaFetch(`${apiUrl}/oauth/agent-token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body)
        });

        if (!response.ok) {
          const errText = await response.text();
          throw new Error(`Agent token creation failed (${response.status}): ${errText}`);
        }

        const result = await response.json();

        if (opts.output === 'json') {
          console.log(JSON.stringify(result, null, 2));
          return;
        }

        console.log('✅ Agent token created.');
        if (result.access_token) {
          console.log(`   Access Token: ${result.access_token}`);
        }
        if (result.token_type) console.log(`   Token Type: ${result.token_type}`);
        if (result.expires_in) console.log(`   Expires In: ${result.expires_in}s`);
        if (result.scope) console.log(`   Scopes: ${result.scope}`);
        if (result.agent_type) console.log(`   Agent Type: ${result.agent_type}`);
        if (result.task_id) console.log(`   Task ID: ${result.task_id}`);
        if (result.task_description) console.log(`   Task: ${result.task_description}`);
        if (result.delegation_depth !== undefined) console.log(`   Delegation Depth: ${result.delegation_depth}`);
      } catch (e) {
        handleError(e);
      }
    });
}
