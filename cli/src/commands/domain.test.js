import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './domain.js';

describe('domain', () => {
  const p = makeProgram();
  register(p);

  it('registers domain commands', () => {
    assertRegistered(p, 'domain');
    assertRegistered(p, 'domain list');
    assertRegistered(p, 'domain register');
    assertRegistered(p, 'domain grant');
    assertRegistered(p, 'domain revoke');
    assertRegistered(p, 'domain roles');
  });
});
