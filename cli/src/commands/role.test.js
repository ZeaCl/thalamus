import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './role.js';

describe('role', () => {
  const p = makeProgram();
  register(p);

  it('registers role commands', () => {
    assertRegistered(p, 'role');
    assertRegistered(p, 'role list');
    assertRegistered(p, 'role show');
    assertRegistered(p, 'role create');
    assertRegistered(p, 'role update');
    assertRegistered(p, 'role delete');
  });
});
