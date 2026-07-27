import zeaFetch from '../lib/http.js';
import { getClient } from '../lib/client.js';
import { getGlobalOpts } from '../lib/globals.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const tokenCmd = program.command('token').description('Personal Access Token (PAT) commands');

  tokenCmd.command('create')
    .description('Create a new Personal Access Token')
    .requiredOption('--name <name>', 'Token description / name')
    .action(async (options) => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();

        const body = {
          name: options.name,
          organization_id: client.activeOrgId
        };

        if (opts.dryRun) {
          console.log('⚠️  DRY RUN — would execute:');
          console.log(`   POST ${client.apiUrl}/api/personal-access-tokens`);
          console.log(`   Body: ${JSON.stringify(body, null, 2)}`);
          return;
        }

        const response = await zeaFetch(`${client.apiUrl}/api/personal-access-tokens`, {
          method: 'POST',
          headers: client.headers,
          body: JSON.stringify(body)
        });

        if (!response.ok) {
          const errText = await response.text();
          throw new Error(`Failed to generate token: ${errText}`);
        }

        const result = await response.json();
        console.log('Personal Access Token generated successfully!');
        console.log('--------------------------------------------------');
        console.log(`Token Value: ${result.token}`);
        console.log('--------------------------------------------------');
        console.log('WARNING: Store this token safely. It will not be shown again.');
      } catch (e) {
        handleError(e);
      }
    });

  tokenCmd.command('list')
    .description('List active Personal Access Tokens')
    .action(async () => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/personal-access-tokens`, { headers: client.headers });
        if (!response.ok) throw new Error(`Failed to list tokens: status ${response.status}`);

        const result = await response.json();
        const pats = result.data || [];

        const filtered = pats.filter(p => !client.activeOrgId || p.organization_id === client.activeOrgId);

        if (filtered.length === 0) {
          console.log('No active tokens under the current organization.');
          return;
        }

        console.log('Active Tokens:');
        filtered.forEach(p => {
          console.log(`- ${p.name} (Prefix: ${p.token_prefix}..., ID: ${p.id}, Active: ${p.is_active})`);
        });
      } catch (e) {
        handleError(e);
      }
    });

  tokenCmd.command('revoke <token_id>')
    .description('Revoke an active Personal Access Token')
    .action(async (tokenId) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/personal-access-tokens/${tokenId}`, {
          method: 'DELETE',
          headers: client.headers
        });

        if (!response.ok) {
          throw new Error(`Failed to revoke token: status ${response.status}`);
        }

        console.log(`Token ${tokenId} revoked successfully.`);
      } catch (e) {
        handleError(e);
      }
    });

  tokenCmd.command('introspect')
    .description('Introspect a token (RFC 7662)')
    .requiredOption('--token <token>', 'Access or refresh token to introspect')
    .option('--token-type-hint <type>', 'Hint: access_token or refresh_token')
    .action(async (options) => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();

        const body = { token: options.token };
        if (options.tokenTypeHint) body.token_type_hint = options.tokenTypeHint;

        if (opts.dryRun) {
          console.log('⚠️  DRY RUN — would execute:');
          console.log(`   POST ${client.apiUrl}/oauth/introspect`);
          console.log(`   Body: ${JSON.stringify(body, null, 2)}`);
          return;
        }

        const response = await zeaFetch(`${client.apiUrl}/oauth/introspect`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body)
        });

        if (!response.ok) {
          const errText = await response.text();
          throw new Error(`Introspection failed (${response.status}): ${errText}`);
        }

        const result = await response.json();

        if (opts.output === 'json') {
          console.log(JSON.stringify(result, null, 2));
          return;
        }

        console.log('Token Introspection:');
        console.log(`  Active: ${result.active}`);
        if (result.active) {
          if (result.scope) console.log(`  Scopes: ${result.scope}`);
          if (result.client_id) console.log(`  Client ID: ${result.client_id}`);
          if (result.username) console.log(`  Username: ${result.username}`);
          if (result.sub) console.log(`  Subject: ${result.sub}`);
          if (result.token_type) console.log(`  Token Type: ${result.token_type}`);
          if (result.exp) console.log(`  Expires: ${new Date(result.exp * 1000).toISOString()}`);
          if (result.iat) console.log(`  Issued At: ${new Date(result.iat * 1000).toISOString()}`);
          if (result.organization_id) console.log(`  Organization: ${result.organization_id}`);
          if (result.agent_type) console.log(`  Agent Type: ${result.agent_type}`);
          if (result.task_id) console.log(`  Task ID: ${result.task_id}`);
          if (result.delegation_depth !== undefined) console.log(`  Delegation Depth: ${result.delegation_depth}`);
        }
      } catch (e) {
        handleError(e);
      }
    });
}
