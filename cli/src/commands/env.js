import zeaFetch from '../lib/http.js';
import { getClient } from '../lib/client.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const envCmd = program.command('env').description('Environment management commands');

  envCmd.command('list <org_id>')
    .description('List environments for an organization')
    .action(async (orgId) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${orgId}/environments`, {
          method: 'GET',
          headers: client.headers
        });
        if (!response.ok) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
      } catch (e) {
        handleError(e);
      }
    });

  envCmd.command('get <org_id> <id_or_slug>')
    .description('Get an environment by ID or slug')
    .action(async (orgId, idOrSlug) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${orgId}/environments/${idOrSlug}`, {
          method: 'GET',
          headers: client.headers
        });
        if (!response.ok) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
      } catch (e) {
        handleError(e);
      }
    });

  envCmd.command('create <org_id>')
    .description('Create an environment for an organization')
    .requiredOption('--slug <slug>', 'Environment slug (e.g. dev, staging, prod)')
    .requiredOption('--name <name>', 'Display name')
    .option('--type <type>', 'Environment type (production, staging, development, sandbox, demo)', 'development')
    .option('--description <description>', 'Description')
    .option('--default', 'Set as default environment', false)
    .action(async (orgId, options) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${orgId}/environments`, {
          method: 'POST',
          headers: client.headers,
          body: JSON.stringify({
            slug: options.slug,
            name: options.name,
            type: options.type,
            description: options.description,
            is_default: options.default
          })
        });
        if (!response.ok) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
      } catch (e) {
        handleError(e);
      }
    });

  envCmd.command('update <org_id> <id_or_slug>')
    .description('Update an environment')
    .option('--name <name>', 'Display name')
    .option('--type <type>', 'Environment type')
    .option('--description <description>', 'Description')
    .action(async (orgId, idOrSlug, options) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${orgId}/environments/${idOrSlug}`, {
          method: 'PATCH',
          headers: client.headers,
          body: JSON.stringify(options)
        });
        if (!response.ok) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
      } catch (e) {
        handleError(e);
      }
    });

  envCmd.command('delete <org_id> <id_or_slug>')
    .description('Delete or archive an environment')
    .option('--force', 'Force delete production environment', false)
    .action(async (orgId, idOrSlug, options) => {
      try {
        const client = await getClient();
        let url = `${client.apiUrl}/api/organizations/${orgId}/environments/${idOrSlug}`;
        if (options.force) url += '?force=true';
        const response = await zeaFetch(url, {
          method: 'DELETE',
          headers: client.headers
        });
        if (!response.ok && response.status !== 204) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        console.log(`Environment ${idOrSlug} deleted successfully`);
      } catch (e) {
        handleError(e);
      }
    });

  envCmd.command('set-default <org_id> <id_or_slug>')
    .description('Set an environment as default for an organization')
    .action(async (orgId, idOrSlug) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${orgId}/environments/${idOrSlug}/default`, {
          method: 'POST',
          headers: client.headers
        });
        if (!response.ok) {
          const err = await response.json();
          throw new Error(err.error || `HTTP ${response.status}`);
        }
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
      } catch (e) {
        handleError(e);
      }
    });
}
