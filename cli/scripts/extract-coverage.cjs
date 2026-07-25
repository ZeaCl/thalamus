#!/usr/bin/env node
/**
 * Extracts actual API endpoint → CLI command from zea-thalamus source.
 * Parses commander.js registrations + zeaFetch()/fetch() calls.
 */
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'src', 'commands');
const LIB = path.join(__dirname, '..', 'src', 'lib');

// Also scan lib/ for API calls made by helper functions (e.g., handleDirectLogin)
const ALL_FILES = [
  ...fs.readdirSync(DIR).filter(f => f.endsWith('.js')).map(f => path.join(DIR, f)),
  ...fs.readdirSync(LIB).filter(f => f.endsWith('.js')).map(f => path.join(LIB, f)),
];

const result = {};

// ── Pass 1: extract commands from command files ────────────────
for (const fp of ALL_FILES) {
  if (fp.includes('.test.')) continue;
  Object.assign(result, parseFile(fp, path.basename(fp).replace('.js', '')));
}

// Normalize and dedup
const deduped = {};
for (const [route, cmd] of Object.entries(result)) {
  const norm = route.replace(/\$\{[^}]+\}/g, ':p');
  if (!deduped[norm]) deduped[norm] = cmd;
}

process.stdout.write(JSON.stringify(deduped, null, 2));

// ── parser ─────────────────────────────────────────────────────

function parseFile(filepath, moduleName) {
  const src = fs.readFileSync(filepath, 'utf8');
  const cmds = {};

  // Build varMap: variable → command name
  const varMap = {};
  const varRe = /(?:const|let|var)\s+(\w+)\s*=\s*(?:\w+\.)?command\(['"]([^'"]+)['"]\)/g;
  let m;
  while ((m = varRe.exec(src)) !== null) varMap[m[1]] = m[2];

  // Find all .command('name').action(...) blocks and extract endpoints
  // More robust: find command+action pairs by scanning for action callbacks
  const actionPattern = /\.action\s*\(\s*(?:async\s*)?(?:\([^)]*\))\s*=>\s*\{/g;
  while ((m = actionPattern.exec(src)) !== null) {
    const actionStart = m.index;
    const bodyStart = actionStart + m[0].length;
    const bodyEnd = findBrace(src, bodyStart);
    if (bodyEnd === -1) continue;
    const body = src.substring(bodyStart, bodyEnd);

    // Find the closest preceding .command('name') 
    const before = src.substring(0, actionStart);
    const cmdMatches = [...before.matchAll(/(?:\.command\(['"]([^'"]+)['"]\))/g)];
    if (cmdMatches.length === 0) continue;

    const lastCmd = cmdMatches[cmdMatches.length - 1];
    const cmdName = lastCmd[1];

    // Try to resolve full chain via varMap
    const prefix = before.substring(0, lastCmd.index);
    const varRef = prefix.match(/(\w+)\.command\(/);
    // Find the last variable assignment before this command
    let chain = [];
    if (varRef && varMap[varRef[1]]) chain.push(varMap[varRef[1]]);
    // If module is a command file (not lib), use module name as top-level command
    if (!ALL_FILES.find(f => f.includes('lib/'))) {
      // This is a command file — moduleName is the top-level command
    }
    chain.push(cmdName);
    const fullCmd = chain.join(' ');

    // Extract endpoints
    const eps = extractEndpoints(body);
    for (const ep of eps) {
      if (!cmds[ep]) cmds[ep] = fullCmd;
    }
  }

  // Also detect direct program.command() patterns (for top-level commands)
  // E.g., program.command('health').action(async () => { ... })
  const topPattern = /program\.command\(['"]([^'"]+)['"]\)[\s\S]*?\.action\s*\(\s*(?:async\s*)?(?:\([^)]*\))\s*=>\s*\{/g;
  while ((m = topPattern.exec(src)) !== null) {
    const cmdName = m[1];
    const bodyStart = m.index + m[0].length;
    const bodyEnd = findBrace(src, bodyStart);
    if (bodyEnd === -1) continue;
    const body = src.substring(bodyStart, bodyEnd);
    const eps = extractEndpoints(body);
    for (const ep of eps) {
      if (!cmds[ep]) cmds[ep] = cmdName;
    }
  }

  // For lib files (client.js, etc): extract endpoints without command mapping
  // These are helper functions called by commands. We map them via the function name.
  if (filepath.includes('lib/')) {
    // Find exported async functions that call APIs
    const fnPattern = /export\s+(?:async\s+)?function\s+(\w+)/g;
    while ((m = fnPattern.exec(src)) !== null) {
      const fnName = m[1];
      const fnStart = m.index;
      const bodyStart = src.indexOf('{', fnStart) + 1;
      const bodyEnd = findBrace(src, bodyStart);
      if (bodyEnd === -1) continue;
      const body = src.substring(bodyStart, bodyEnd);
      const eps = extractEndpoints(body);
      // Don't map lib functions directly; they'll be picked up via cross-reference
    }
  }

  // Cross-reference: find commands that call lib functions
  const callPattern = /(?:await\s+)?(\w+)\(/g;
  // This is complex — skip for now, handle known cases manually

  return cmds;
}

function findBrace(src, start) {
  let d = 1;
  for (let i = start; i < src.length; i++) {
    if (src[i] === '{') d++;
    if (src[i] === '}') d--;
    if (d === 0) return i;
  }
  return -1;
}

// ── endpoints ──────────────────────────────────────────────────

function extractEndpoints(body) {
  const eps = new Set();
  // Match: ${...apiUrl}/api/path or ${...apiUrl}/oauth/path or hardcoded /api/path
  const patterns = [
    /\$\{[^}]*apiUrl\}\/(api\/[^`'"\s?]+)/g,
    /\$\{[^}]*apiUrl\}\/(oauth\/[^`'"\s?]+)/g,
    /['"](\/api\/[^'"\s?]+)['"]/g,
  ];
  for (const re of patterns) {
    let m;
    while ((m = re.exec(body)) !== null) {
      let p = '/' + m[1].replace(/\/$/, '');
      const method = inferMethod(body);
      eps.add(`${method} ${p}`);
    }
  }
  return [...eps];
}

function inferMethod(body) {
  const m = body.match(/method:\s*['"](GET|POST|PUT|PATCH|DELETE)['"]/i);
  return m ? m[1].toUpperCase() : 'GET';
}
