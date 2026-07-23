#!/usr/bin/env node

import { Command } from 'commander';
import { readFileSync } from 'fs';

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

// ═══ Command files ══════════════════════════════════════
import { register as registerAuth } from '../src/commands/auth.js';
import { register as registerOrg } from '../src/commands/org.js';
import { register as registerToken } from '../src/commands/token.js';
import { register as registerConfig } from '../src/commands/config.js';
import { register as registerHealth } from '../src/commands/health.js';
import { register as registerDoctor } from '../src/commands/doctor.js';
import { register as registerClient } from '../src/commands/client.js';
import { register as registerDomain } from '../src/commands/domain.js';
import { register as registerUser } from '../src/commands/user.js';
import { register as registerMfa } from '../src/commands/mfa.js';
import { register as registerSecret } from '../src/commands/secret.js';
import { register as registerAdmin } from '../src/commands/admin.js';
import { register as registerAudit } from '../src/commands/audit.js';

// ═══ Program ════════════════════════════════════════════
const program = new Command();

program
  .name('zea-thalamus')
  .description('ZEA Thalamus — Identity & Access Management')
  .version(pkg.version)
  .option('--output <format>', 'Output format: json, table, text', 'table')
  .option('--debug', 'Show HTTP request/response details', false)
  .option('--dry-run', 'Validate without executing', false)
  .option('--quiet', 'Suppress non-essential output', false)
  .option('--no-color', 'Disable ANSI colors', false);

// ═══ Register all commands ══════════════════════════════
registerConfig(program);
registerAuth(program);
registerOrg(program);
registerToken(program);
registerHealth(program);
registerDoctor(program);
registerClient(program);
registerDomain(program);
registerUser(program);
registerMfa(program);
registerSecret(program);
registerAdmin(program);
registerAudit(program);

// ═══ Dynamic command discovery (--zea-discover) ═════
// Used by zea-cli to auto-discover available commands for
// smoke testing, help generation, and validation.
if (process.argv.includes('--zea-discover')) {
  const commands = {};
  function walk(cmds, prefix = '') {
    for (const cmd of cmds) {
      const name = prefix ? prefix + ' ' + cmd.name() : cmd.name();
      if (cmd.description()) commands[name] = cmd.description();
      walk(cmd.commands, name);
    }
  }
  walk(program.commands);
  console.log(JSON.stringify({
    description: 'Identity & Access Management',
    commands
  }, null, 2));
  process.exit(0);
}

// ═══ Agent manifest (--zea-manifest) ═════════════════
// Full metadata export for AI agents and doc generation.
// Includes options, arguments, and auth requirements.
if (process.argv.includes('--zea-manifest')) {
  const PUBLIC_COMMANDS = new Set([
    'health', 'oidc', 'config', 'login', 'set-token', 'whoami', 'doctor'
  ]);

  function extractOptions(cmd) {
    return cmd.options.map(o => ({
      name: o.long || o.short,
      short: o.short || null,
      type: o.attributeName?.() || 'string',
      description: o.description || '',
      required: o.required || false,
      default: o.defaultValue
    }));
  }

  function extractArgs(cmd) {
    if (!cmd._args) return [];
    return cmd._args.map(a => ({
      name: a._name,
      required: a.required || false,
      description: a.description || ''
    }));
  }

  const commands = {};
  function walk(cmds, prefix = '') {
    for (const cmd of cmds) {
      const name = prefix ? prefix + ' ' + cmd.name() : cmd.name();
      const isPublic = PUBLIC_COMMANDS.has(name) ||
        [...PUBLIC_COMMANDS].some(p => name.startsWith(p + ' '));

      commands[name] = {
        description: cmd.description() || '',
        options: extractOptions(cmd),
        arguments: extractArgs(cmd),
        auth: !isPublic
      };
      walk(cmd.commands, name);
    }
  }
  walk(program.commands);

  console.log(JSON.stringify({
    service: 'thalamus',
    version: pkg.version,
    description: 'Identity & Access Management',
    endpoints: {
      default: 'http://auth.zea.localhost',
      env_override: 'THALAMUS_API_URL | ZEA_API_URL'
    },
    commands
  }, null, 2));
  process.exit(0);
}

program.parse(process.argv);
