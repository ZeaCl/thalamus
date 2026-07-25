import { describe, it } from 'node:test';
import assert from 'node:assert';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './client.js';

describe('client', () => {
  const p = makeProgram();
  register(p);

  it('registers client commands', () => {
    assertRegistered(p, 'client');
    assertRegistered(p, 'client list');
    assertRegistered(p, 'client show');
    assertRegistered(p, 'client create');
    assertRegistered(p, 'client update');
    assertRegistered(p, 'client delete');
    assertRegistered(p, 'client rotate-secret');
    assertRegistered(p, 'client validate');
    assertRegistered(p, 'client trust');
    assertRegistered(p, 'client add-redirect-uri');
  });

  it('client create has required options', () => {
    const cmd = assertRegistered(p, 'client create');
    const opts = cmd._options.map(o => o.flags);
    assert(opts.some(o => o.includes('name')), 'should have --name');
    assert(opts.some(o => o.includes('type')), 'should have --type');
  });

  it('client trust has --on/--off', () => {
    const cmd = assertRegistered(p, 'client trust');
    const opts = cmd._options.map(o => o.flags);
    assert(opts.some(o => o.includes('on')), 'should have --on');
  });

  it('all commands have handlers', () => {
    for (const name of ['list', 'show', 'create', 'update', 'delete', 'trust']) {
      const cmd = assertRegistered(p, `client ${name}`);
      assert(typeof cmd._handler === 'function', `client ${name} should have handler`);
    }
  });
});
