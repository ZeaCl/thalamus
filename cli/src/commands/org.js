import zeaFetch from '../lib/http.js';
import { getClient, loadConfig, saveConfig } from '../lib/client.js';
import { handleError } from '../lib/errors.js';

export function register(program) {
  const org = program.command('org').description('Organization management commands');

  org.command('list')
    .description('List organizations')
    .action(async () => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        
        if (!response.ok) {
          throw new Error(`Failed to fetch user info: status ${response.status}`);
        }

        const info = await response.json();
        const orgs = info.organizations || [];

        if (orgs.length === 0) {
          console.log('No organizations found.');
          return;
        }

        console.log('Organizations:');
        orgs.forEach(o => {
          const activeMarker = o.id === client.activeOrgId ? '* ' : '  ';
          console.log(`${activeMarker}${o.name} (Slug: ${o.slug || 'N/A'}, ID: ${o.id})`);
        });
      } catch (e) {
        handleError(e);
      }
    });

  org.command('switch <org_id_or_slug>')
    .description('Switch default organization context')
    .action(async (target) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!response.ok) throw new Error(`HTTP error ${response.status}`);

        const info = await response.json();
        const orgs = info.organizations || [];
        const match = orgs.find(o => o.id === target || o.slug === target);

        if (!match) {
          throw new Error(`Organization '${target}' not found in your membership list.`);
        }

        const config = await loadConfig();
        config.activeOrgId = match.id;
        await saveConfig(config);
        console.log(`Active organization context switched to: ${match.name} (${match.id})`);
      } catch (e) {
        handleError(e);
      }
    });

  org.command('create')
    .description('Create a new organization')
    .requiredOption('--name <name>', 'Name of the organization')
    .requiredOption('--email <email>', 'Owner email address')
    .option('--plan <plan>', 'Plan type (free, basic, standard, premium, enterprise)', 'free')
    .action(async (options) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/api/organizations`, {
          method: 'POST',
          headers: client.headers,
          body: JSON.stringify({
            name: options.name,
            owner_email: options.email,
            plan_type: options.plan
          })
        });

        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.error || `HTTP error ${response.status}`);
        }

        const result = await response.json();
        const savedOrg = result.data;
        console.log(`Organization '${savedOrg.name}' created successfully!`);
        console.log(`ID: ${savedOrg.id}`);
        console.log(`Owner: ${savedOrg.owner_email}`);
        console.log(`Plan: ${savedOrg.plan_type}`);
      } catch (e) {
        handleError(e);
      }
    });

  const memberCmd = org.command('member').description('Organization member management');

  memberCmd.command('add <org_slug>')
    .description('Add a member to an organization by email')
    .requiredOption('--email <email>', 'Email of the user to add')
    .requiredOption('--role <role>', 'Role (admin, member, billing)')
    .action(async (orgSlug, options) => {
      try {
        const client = await getClient();
        const userinfoResponse = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!userinfoResponse.ok) throw new Error(`HTTP error ${userinfoResponse.status}`);

        const info = await userinfoResponse.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === orgSlug || o.slug === orgSlug);

        if (!org) throw new Error(`Organization '${orgSlug}' not found in your memberships.`);

        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}/members`, {
          method: 'POST',
          headers: client.headers,
          body: JSON.stringify({
            email: options.email,
            role: options.role
          })
        });

        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.error || `HTTP error ${response.status}`);
        }

        const result = await response.json();
        console.log(`Member '${options.email}' added to '${org.name}' as ${options.role}.`);
      } catch (e) {
        handleError(e);
      }
    });

  memberCmd.command('remove <org_slug>')
    .description('Remove a member from an organization by user ID')
    .requiredOption('--user-id <user_id>', 'User ID to remove')
    .action(async (orgSlug, options) => {
      try {
        const client = await getClient();
        const userinfoResponse = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!userinfoResponse.ok) throw new Error(`HTTP error ${userinfoResponse.status}`);

        const info = await userinfoResponse.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === orgSlug || o.slug === orgSlug);

        if (!org) throw new Error(`Organization '${orgSlug}' not found in your memberships.`);

        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}/members/${options.userId}`, {
          method: 'DELETE',
          headers: client.headers
        });

        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.error || `HTTP error ${response.status}`);
        }

        const result = await response.json();
        console.log(`Member '${options.userId}' removed from '${org.name}'.`);
      } catch (e) {
        handleError(e);
      }
    });

  memberCmd.command('list <org_slug>')
    .description('List members of an organization')
    .action(async (orgSlug) => {
      try {
        const client = await getClient();
        const userinfoResponse = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!userinfoResponse.ok) throw new Error(`HTTP error ${userinfoResponse.status}`);

        const info = await userinfoResponse.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === orgSlug || o.slug === orgSlug);

        if (!org) throw new Error(`Organization '${orgSlug}' not found in your memberships.`);

        const response = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}`, { headers: client.headers });
        if (!response.ok) throw new Error(`HTTP error ${response.status}`);

        const result = await response.json();
        const members = result.data.members || [];

        if (members.length === 0) {
          console.log(`No members in '${org.name}'.`);
          return;
        }

        console.log(`Members of '${org.name}':`);
        members.forEach(m => {
          const userId = m.user_id || '(pending invite)';
          const email = m.email || '(email pending)';
          console.log(`  ${email} — ${m.role} (ID: ${userId})`);
        });
      } catch (e) {
        handleError(e);
      }
    });

  // ── show ───────────────────────────────────────────
  org.command('show <slug_or_id>')
    .description('Show organization details')
    .action(async (target) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!response.ok) throw new Error(`HTTP error ${response.status}`);

        const info = await response.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);

        if (!org) throw new Error(`Organization '${target}' not found in your memberships.`);

        // Get full org details
        const detailResp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}`, { headers: client.headers });
        if (!detailResp.ok) throw new Error(`HTTP error ${detailResp.status}`);
        const o = (await detailResp.json()).data;

        console.log(`   Name:      ${o.name}`);
        console.log(`   ID:        ${o.id}`);
        console.log(`   Plan:      ${o.plan_type}`);
        console.log(`   Status:    ${o.status}`);
        console.log(`   Verified:  ${o.verified ? '✅' : '❌'}`);
        console.log(`   Members:   ${o.current_user_count || (o.members || []).length}`);
        console.log(`   Max Users: ${o.max_users}`);
        if (o.domains && o.domains.length > 0) {
          console.log(`   Domains:   ${o.domains.join(', ')}`);
        }
      } catch (e) {
        handleError(e);
      }
    });

  // ── update ─────────────────────────────────────────
  org.command('update <slug_or_id>')
    .description('Update organization name or plan')
    .option('--name <name>', 'New organization name')
    .option('--plan <plan>', 'New plan: free, basic, standard, premium, enterprise')
    .action(async (target, options) => {
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!response.ok) throw new Error(`HTTP error ${response.status}`);

        const info = await response.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);
        if (!org) throw new Error(`Organization '${target}' not found.`);

        const body = {};
        if (options.name) body.name = options.name;
        if (options.plan) body.plan_type = options.plan;

        const updateResp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}`, {
          method: 'PATCH', headers: client.headers, body: JSON.stringify(body)
        });
        if (!updateResp.ok) throw new Error(`HTTP error ${updateResp.status}`);
        console.log('✅ Organization updated.');
      } catch (e) {
        handleError(e);
      }
    });

  // ── delete ─────────────────────────────────────────
  org.command('delete <slug_or_id>')
    .description('Delete an organization')
    .action(async (target) => {
      const opts = getGlobalOpts();
      try {
        const client = await getClient();
        const response = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!response.ok) throw new Error(`HTTP error ${response.status}`);

        const info = await response.json();
        const orgs = info.organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);
        if (!org) throw new Error(`Organization '${target}' not found.`);

        if (opts.dryRun) {
          console.log(`⚠️  DRY RUN — would DELETE /api/organizations/${org.id}`);
          return;
        }

        const delResp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}`, {
          method: 'DELETE', headers: client.headers
        });
        if (!delResp.ok) throw new Error(`HTTP error ${delResp.status}`);
        console.log('✅ Organization deleted.');
      } catch (e) {
        handleError(e);
      }
    });

  // ── saml ───────────────────────────────────────────
  const samlCmd = org.command('saml').description('SAML SSO configuration');

  samlCmd.command('show <slug_or_id>')
    .description('Show SAML configuration')
    .action(async (target) => {
      try {
        const client = await getClient();
        const infoResp = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!infoResp.ok) throw new Error(`HTTP error ${infoResp.status}`);
        const orgs = (await infoResp.json()).organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);
        if (!org) throw new Error(`Organization '${target}' not found.`);

        const resp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}/saml-config`, { headers: client.headers });
        if (!resp.ok) {
          if (resp.status === 404) { console.log('No SAML configuration found for this organization.'); return; }
          throw new Error(`HTTP error ${resp.status}`);
        }
        const data = (await resp.json()).data;
        console.log(`   Name:         ${data.name}`);
        console.log(`   Entity ID:    ${data.idp_entity_id}`);
        console.log(`   SSO URL:      ${data.idp_sso_url}`);
        console.log(`   Enabled:      ${data.enabled ? '✅' : '❌'}`);
        console.log(`   JIT:          ${data.jit_provisioning ? '✅' : '❌'}`);
        if (data.allowed_domains?.length) console.log(`   Domains:      ${data.allowed_domains.join(', ')}`);
      } catch (e) {
        handleError(e);
      }
    });

  samlCmd.command('set <slug_or_id>')
    .description('Set SAML configuration')
    .requiredOption('--entity-id <id>', 'Identity Provider entity ID')
    .requiredOption('--sso-url <url>', 'Identity Provider SSO URL')
    .requiredOption('--cert <cert>', 'Identity Provider X.509 certificate (PEM)')
    .option('--name <name>', 'Configuration name')
    .option('--enable', 'Enable SAML')
    .option('--disable', 'Disable SAML')
    .option('--jit', 'Enable Just-In-Time provisioning')
    .option('--domains <domains>', 'Comma-separated allowed domains')
    .action(async (target, options) => {
      try {
        const client = await getClient();
        const infoResp = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!infoResp.ok) throw new Error(`HTTP error ${infoResp.status}`);
        const orgs = (await infoResp.json()).organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);
        if (!org) throw new Error(`Organization '${target}' not found.`);

        const body = {
          idp_entity_id: options.entityId,
          idp_sso_url: options.ssoUrl,
          idp_cert: options.cert,
        };
        if (options.name) body.name = options.name;
        if (options.enable) body.enabled = true;
        if (options.disable) body.enabled = false;
        if (options.jit) body.jit_provisioning = true;
        if (options.domains) body.allowed_domains = options.domains.split(',').map(s => s.trim()).filter(Boolean);

        const resp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}/saml-config`, {
          method: 'PUT', headers: client.headers, body: JSON.stringify(body)
        });
        if (!resp.ok) {
          const err = await resp.json().catch(() => ({}));
          throw new Error(err.error || `HTTP error ${resp.status}`);
        }
        console.log('✅ SAML configuration updated.');
      } catch (e) {
        handleError(e);
      }
    });

  samlCmd.command('delete <slug_or_id>')
    .description('Delete SAML configuration')
    .action(async (target) => {
      try {
        const client = await getClient();
        const infoResp = await zeaFetch(`${client.apiUrl}/oauth/userinfo`, { headers: client.headers });
        if (!infoResp.ok) throw new Error(`HTTP error ${infoResp.status}`);
        const orgs = (await infoResp.json()).organizations || [];
        const org = orgs.find(o => o.id === target || o.slug === target);
        if (!org) throw new Error(`Organization '${target}' not found.`);

        const resp = await zeaFetch(`${client.apiUrl}/api/organizations/${org.id}/saml-config`, {
          method: 'DELETE', headers: client.headers
        });
        if (!resp.ok) throw new Error(`HTTP error ${resp.status}`);
        console.log('✅ SAML configuration deleted.');
      } catch (e) {
        handleError(e);
      }
    });
}
