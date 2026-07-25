#!/usr/bin/env node
/**
 * Extracts CLI test coverage from real source code.
 *
 * Unit tests: checks cli/src/commands/*.test.js per command file
 * E2E tests:  maps functions in scripts/test-cli.sh to commands
 *
 * Command list: obtained from zea-thalamus --zea-discover (canonical).
 * No contracts, no manifests — just real code.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const REPO_ROOT = path.join(__dirname, '..', '..');
const COMMANDS_DIR = path.join(__dirname, '..', 'src', 'commands');
const E2E_SCRIPT = path.join(REPO_ROOT, 'scripts', 'test-cli.sh');

// ── 1. Get canonical command list from CLI ─────────────────────
let allCommands = [];
try {
  const raw = execSync('zea-thalamus --zea-discover', {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'ignore']
  });
  const manifest = JSON.parse(raw);
  allCommands = Object.keys(manifest.commands).sort();
} catch {
  // Fallback: try running from local bin
  try {
    const bin = path.join(__dirname, '..', 'bin', 'zea-thalamus.js');
    const raw = execSync(`node "${bin}" --zea-discover`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore']
    });
    allCommands = Object.keys(JSON.parse(raw).commands).sort();
  } catch (e) {
    console.error('Cannot get command list:', e.message);
    allCommands = [];
  }
}

// ── 2. Find unit test files ────────────────────────────────────
const testFiles = fs.readdirSync(COMMANDS_DIR).filter(f => f.endsWith('.test.js'));
const unitCoveredModules = new Set(testFiles.map(f => f.replace('.test.js', '')));
const unitCovered = new Set();
for (const file of testFiles) {
  const cmdName = file.replace('.test.js', '');
  unitCovered.add(cmdName);
  // Also find describe/test blocks within
  const src = fs.readFileSync(path.join(COMMANDS_DIR, file), 'utf8');
  const re = /(?:describe|test|it)\s*\(\s*['"]([^'"]+)['"]/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    unitCovered.add(m[1]);
  }
}

// ── 3. Find E2E test functions ─────────────────────────────────
const e2eFns = [];
if (fs.existsSync(E2E_SCRIPT)) {
  const src = fs.readFileSync(E2E_SCRIPT, 'utf8');
  const re = /^test_(\w+)\s*\(\s*\)\s*\{/gm;
  let m;
  while ((m = re.exec(src)) !== null) {
    e2eFns.push(m[1]);
  }
}

// ── 4. Match commands to tests ─────────────────────────────────
function e2eMatches(cmd, fns) {
  const parts = cmd.split(' ');
  for (const fn of fns) {
    // Direct match: health ↔ test_health
    if (fn === cmd.replace(/\s+/g, '_')) return fn;
    // Command is prefix: client ↔ test_client
    if (fn === parts[0]) return fn;
    // E2E fn contains command: client_create ↔ client create
    if (fn.startsWith(parts[0] + '_')) return fn;
    // E2E fn ends with command: invalid_login ↔ login
    if (fn.endsWith('_' + parts[0])) return fn;
    // E2E fn contains all command parts: setup_oauth ↔ mfa setup
    const fnParts = fn.split('_');
    if (parts.every(p => fnParts.includes(p))) return fn;
    // test_org covers org list, org show, etc
    if (fn === parts[0] && cmd.startsWith(fn + ' ')) return fn;
    // test_client covers client list, client create, etc
    if (fn === parts[0]) return fn;
  }
  return null;
}

// ── 5. Build report ────────────────────────────────────────────
const commands = {};
for (const cmd of allCommands) {
  const e2eFn = e2eMatches(cmd, e2eFns);
  // Manual module-to-command mappings for top-level commands that
  // don't match their module name (e.g., 'logout' is in auth.js)
  const moduleMap = {
    logout: 'auth', 'set-token': 'auth',
    avatar: 'account', 'register': 'account',
    'verify-email': 'account', 'resend-verification': 'account',
  };

  const unit = unitCovered.has(cmd.replace(/\s+/g, '_')) ||
               unitCovered.has(cmd.split(' ')[0]) ||
               unitCoveredModules.has(cmd.split(' ')[0]) ||
               (moduleMap[cmd.split(' ')[0]] && unitCoveredModules.has(moduleMap[cmd.split(' ')[0]])) ||
               [...unitCovered, ...unitCoveredModules].some(d =>
                 d.includes(cmd.split(' ')[0]) || cmd.startsWith(d + ' ')
               );

  commands[cmd] = {
    cmd,
    unit,
    e2e: e2eFn !== null,
    e2e_test_fn: e2eFn ? `test_${e2eFn}` : null,
  };
}

const summary = {
  total_commands: allCommands.length,
  unit_covered: Object.values(commands).filter(c => c.unit).length,
  e2e_covered: Object.values(commands).filter(c => c.e2e).length,
  unit_test_files: testFiles.length,
  e2e_test_functions: e2eFns.length,
};

process.stdout.write(JSON.stringify({ _summary: summary, commands }, null, 2));
