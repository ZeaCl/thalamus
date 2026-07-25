import { describe, it } from 'node:test';
import assert from 'node:assert';

/**
 * Unit test pattern for CLI commands.
 *
 * Tests command structure (registration, options, arguments) at unit level.
 * HTTP behavior is tested at E2E level (scripts/test-cli.sh) and contract level.
 *
 * Usage in each .test.js:
 *   import { makeProgram, assertCommand } from '../../test/helpers.js';
 */

/**
 * Creates a fake Commander-like program that captures registered commands.
 */
export function makeProgram() {
  return makeCommand('__root__');
}

function makeCommand(name) {
  return {
    _name: name,
    _description: '',
    _options: [],
    _args: [],
    _handler: null,
    _subcommands: {},
    description(desc) { this._description = desc; return this; },
    option(flags, desc, defaultValue) {
      this._options.push({ flags, desc, defaultValue, required: false });
      return this;
    },
    requiredOption(flags, desc, defaultValue) {
      this._options.push({ flags, desc, defaultValue, required: true });
      return this;
    },
    argument(name, desc) {
      this._args.push({ name, desc });
      return this;
    },
    action(fn) { this._handler = fn; return this; },
    command(subName) {
      const sub = makeCommand(subName);
      this._subcommands[subName] = sub;
      return sub;
    },
  };
}

/**
 * Assert that a command was registered with expected properties.
 */
export function assertCommand(commands, name, expected = {}) {
  const cmd = commands[name];
  assert.ok(cmd, `Command "${name}" not registered. Available: ${Object.keys(commands).join(', ')}`);

  if (expected.description !== undefined) {
    assert.ok(
      cmd._description.includes(expected.description),
      `"${name}" description "${cmd._description}" should include "${expected.description}"`
    );
  }

  if (expected.hasOptions) {
    for (const opt of expected.hasOptions) {
      const found = cmd._options.some(o => o.flags.includes(opt));
      assert.ok(found, `"${name}" should have option --${opt}`);
    }
  }

  if (expected.hasArgs) {
    for (const arg of expected.hasArgs) {
      const found = cmd._args.some(a => a.name === arg);
      assert.ok(found, `"${name}" should have argument <${arg}>`);
    }
  }

  if (expected.hasHandler !== undefined) {
    if (expected.hasHandler) {
      assert.ok(typeof cmd._handler === 'function', `"${name}" should have an action handler`);
    }
  }

  if (expected.subcommands) {
    for (const sub of expected.subcommands) {
      assert.ok(cmd._subcommands[sub], `"${name}" should have subcommand "${sub}"`);
    }
  }

  return cmd;
}

/**
 * Assert that a top-level command or subcommand was registered.
 */
export function assertRegistered(program, commandPath) {
  const parts = commandPath.split(' ');
  let current = program;
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    // Match command names that may include args like "show <id>"
    const match = (name) => name === part || name?.startsWith(part + ' ');
    const keys = Object.keys(current._subcommands || {});
    const foundKey = keys.find(match);

    if (i === parts.length - 1) {
      assert.ok(foundKey, `Command "${commandPath}" not found. Available: ${keys.join(', ')}`);
      return current._subcommands[foundKey];
    }
    assert.ok(foundKey, `Command "${parts.slice(0, i + 1).join(' ')}" not found. Available: ${keys.join(', ')}`);
    current = current._subcommands[foundKey];
  }
}
