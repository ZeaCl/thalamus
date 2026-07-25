#!/usr/bin/env node
/**
 * Real code coverage from node --test --experimental-test-coverage.
 * No more "file exists = covered" fiction.
 */
const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const CLI_DIR = path.join(__dirname, '..');
const COMMANDS_DIR = path.join(CLI_DIR, 'src', 'commands');
const E2E_SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'test-cli.sh');

// ── 1. Run real tests with coverage ─────────────────────────────
let coverage = {};

try {
  const raw = execSync(
    'node --test --experimental-test-coverage "src/commands/*.test.js"',
    { cwd: CLI_DIR, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
  );

  // Parse coverage report from stderr (Node outputs coverage there)
  // Format: "# file.js | line% | branch% | funcs% | uncovered lines"
  const lines = raw.split('\n');
  let inCoverage = false;
  for (const line of lines) {
    if (line.includes('start of coverage report')) {
      inCoverage = true;
      continue;
    }
    if (line.includes('end of coverage report')) break;
    if (!inCoverage) continue;

    const match = line.match(/^#\s+(\S+\.js)\s+\|\s+([\d.]+)\s+\|\s+([\d.]+)\s+\|\s+([\d.]+)\s+\|/);
    if (match) {
      const [, file, lineCov, branchCov, funcCov] = match;
      const name = file.replace(/\.js$/, '');
      if (!file.includes('.test.') && !file.startsWith('lib/') && !file.startsWith('test/')) {
        coverage[name] = {
          file,
          line: parseFloat(lineCov),
          branch: parseFloat(branchCov),
          func: parseFloat(funcCov),
        };
      }
    }
  }
} catch (e) {
  // Tests may have failed — still parse whatever coverage we got
  const raw = e.stdout || e.stderr || '';
  const lines = raw.split('\n');
  let inCoverage = false;
  for (const line of lines) {
    if (line.includes('start of coverage report')) { inCoverage = true; continue; }
    if (line.includes('end of coverage report')) break;
    if (!inCoverage) continue;
    const match = line.match(/^#\s+(\S+\.js)\s+\|\s+([\d.]+)\s+\|\s+([\d.]+)\s+\|\s+([\d.]+)\s+\|/);
    if (match) {
      const [, file, lineCov, branchCov, funcCov] = match;
      const name = file.replace(/\.js$/, '');
      if (!file.includes('.test.') && !file.startsWith('lib/') && !file.startsWith('test/')) {
        coverage[name] = { file, line: parseFloat(lineCov), branch: parseFloat(branchCov), func: parseFloat(funcCov) };
      }
    }
  }
}

// ── 2. Get E2E test functions ───────────────────────────────────
const e2eFns = [];
if (fs.existsSync(E2E_SCRIPT)) {
  const src = fs.readFileSync(E2E_SCRIPT, 'utf8');
  const re = /^test_(\w+)\s*\(\s*\)\s*\{/gm;
  let m;
  while ((m = re.exec(src)) !== null) e2eFns.push(m[1]);
}

// ── 3. Get command list from CLI ────────────────────────────────
let allCommands = [];
try {
  const raw = execSync('zea-thalamus --zea-discover', {
    encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe']
  });
  allCommands = Object.keys(JSON.parse(raw).commands).sort();
} catch {
  allCommands = [];
}

// ── 4. Match commands to coverage ───────────────────────────────
// Commands may be in files with different names (register → account.js)
const cmdToFile = {
  register: 'account', 'verify-email': 'account', 'resend-verification': 'account',
  password: 'account', avatar: 'account',
  logout: 'auth', 'set-token': 'auth', debug: 'auth',
  doctor: 'doctor', 'oidc': 'audit',
};

const commands = {};
for (const cmd of allCommands) {
  const cmdRoot = cmd.split(' ')[0];
  const fileKey = cmdToFile[cmdRoot] || cmdRoot;
  const cov = coverage[fileKey];

  commands[cmd] = {
    cmd,
    unit_line: cov?.line || 0,
    unit_branch: cov?.branch || 0,
    e2e: e2eFns.some(fn =>
      fn === cmdRoot || fn.startsWith(cmdRoot + '_') || fn.endsWith('_' + cmdRoot)
    ),
  };
}

// ── 5. Calculate totals ─────────────────────────────────────────
const cmdList = Object.values(commands);
const coveredFiles = Object.keys(coverage).length;
const totalFiles = fs.readdirSync(COMMANDS_DIR)
  .filter(f => f.endsWith('.js') && !f.endsWith('.test.js'))
  .length;

const avgLine = cmdList.length > 0
  ? cmdList.reduce((s, c) => s + c.unit_line, 0) / cmdList.length
  : 0;

const commandsWithTests = cmdList.filter(c => c.unit_line > 0).length;
const commandsWithE2E = cmdList.filter(c => c.e2e).length;
const commandsWithNeither = cmdList.filter(c => c.unit_line === 0 && !c.e2e).length;

const summary = {
  total_commands: allCommands.length,
  unit_files: totalFiles,
  unit_files_covered: coveredFiles,
  unit_avg_line_coverage: Math.round(avgLine * 100) / 100,
  unit_commands_covered: commandsWithTests,
  e2e_functions: e2eFns.length,
  e2e_commands_covered: commandsWithE2E,
  commands_with_neither: commandsWithNeither,
};

process.stdout.write(JSON.stringify({ _summary: summary, commands }, null, 2));
