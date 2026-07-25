import { describe, it } from 'node:test';
import assert from 'node:assert';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './user.js';

describe('user', () => {
  const p = makeProgram();
  register(p);

  it('registers user commands', () => {
    assertRegistered(p, 'user');
    assertRegistered(p, 'user list');
    assertRegistered(p, 'user show');
    assertRegistered(p, 'user create');
    assertRegistered(p, 'user update');
    assertRegistered(p, 'user unlock');
    assertRegistered(p, 'user delete');
    assertRegistered(p, 'user role');
    assertRegistered(p, 'user scopes');
  });

  it('registers role subcommands', () => {
    assertRegistered(p, 'user role list');
    assertRegistered(p, 'user role assign');
    assertRegistered(p, 'user role revoke');
  });

  it('user create requires email and password', () => {
    const cmd = assertRegistered(p, 'user create');
    const required = cmd._options.filter(o => o.required).map(o => o.flags);
    assert(required.some(o => o.includes('email')), 'should require --email');
    assert(required.some(o => o.includes('password')), 'should require --password');
  });
});
