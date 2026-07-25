import { describe, it } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = path.join(__dirname, 'fixtures');

/**
 * Contract tests — validate response structure from recorded fixtures.
 *
 * These tests catch breaking changes in API response format.
 * Run `node scripts/record-contracts.cjs` to refresh fixtures.
 */

// ── Schema definitions ──────────────────────────────────────────

const SCHEMAS = {
  health: {
    required: ['status'],
    fields: { status: 'string' },
  },
  'oidc-discovery': {
    required: ['issuer', 'authorization_endpoint', 'token_endpoint'],
    fields: { issuer: 'string' },
  },
  jwks: {
    required: ['keys'],
    fields: { keys: 'object' },
  },
  userinfo: {
    required: ['email'],
    fields: { email: 'string', name: 'string', sub: 'string' },
  },
  'clients-list': {
    required: ['data'],
    fields: { data: 'object' },
    itemFields: {
      id: 'string', name: 'string', client_type: 'string',
      redirect_uris: 'object', grant_types: 'object',
    },
  },
  'users-list': {
    required: ['data'],
    fields: { data: 'object' },
    itemFields: { id: 'string', email: 'string', status: 'string' },
  },
  'orgs-list': {
    required: ['data'],
    fields: { data: 'object' },
  },
  'roles-list': {
    required: ['data'],
    fields: { data: 'object' },
  },
  'secrets-list': {
    required: ['data'],
    fields: { data: 'object' },
  },
  'domains-list': {
    required: ['data'],
    fields: { data: 'object' },
  },
  'pats-list': {
    required: ['data'],
    fields: { data: 'object' },
  },
  'admin-api-keys': {
    required: ['data'],
    fields: { data: 'object' },
  },
};

// ── Helpers ─────────────────────────────────────────────────────

function loadFixture(name) {
  const filepath = path.join(FIXTURES_DIR, `${name}.json`);
  if (!fs.existsSync(filepath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(filepath, 'utf8'));
}

function validateSchema(fixture, schema, label) {
  assert.ok(fixture, `${label}: fixture not found`);
  assert.ok(fixture._status >= 200 && fixture._status < 400,
    `${label}: expected 2xx/3xx, got ${fixture._status}`);

  const body = fixture.body;

  for (const field of (schema.required || [])) {
    assert.ok(field in body, `${label}: missing required field "${field}"`);
  }

  for (const [field, type] of Object.entries(schema.fields || {})) {
    if (field in body) {
      if (type === 'object') {
        assert.ok(typeof body[field] === 'object' && body[field] !== null,
          `${label}: "${field}" should be object, got ${typeof body[field]}`);
      } else if (type === 'string') {
        assert.ok(typeof body[field] === 'string',
          `${label}: "${field}" should be string, got ${typeof body[field]}`);
      }
    }
  }

  // Validate first item if it's a data array
  if (schema.itemFields && Array.isArray(body.data)) {
    const items = body.data;
    if (items.length > 0) {
      const item = items[0];
      for (const [field, type] of Object.entries(schema.itemFields)) {
        assert.ok(field in item,
          `${label}: item missing field "${field}"`);
        if (type === 'string') {
          assert.ok(typeof item[field] === 'string',
            `${label}: item.${field} should be string`);
        }
      }
    }
  }
}

// ── Tests ───────────────────────────────────────────────────────

describe('contracts', () => {
  for (const [name, schema] of Object.entries(SCHEMAS)) {
    it(`${name} response matches schema`, () => {
      const fixture = loadFixture(name);
      if (!fixture) {
        console.log(`  ⚠️  ${name}: no fixture — run: node scripts/record-contracts.cjs`);
        return;
      }
      validateSchema(fixture, schema, name);
    });
  }

  it('fixtures directory exists', () => {
    assert.ok(fs.existsSync(FIXTURES_DIR),
      'cli/test/fixtures/ directory not found. Run: node scripts/record-contracts.cjs');
  });

  it('has health fixture', () => {
    assert.ok(loadFixture('health'), 'health.json missing');
  });

  it('has oidc-discovery fixture', () => {
    assert.ok(loadFixture('oidc-discovery'), 'oidc-discovery.json missing');
  });
});
