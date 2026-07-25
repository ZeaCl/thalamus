import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './auth.js';

describe('auth', () => {
  const p = makeProgram();
  register(p);

  it('registers auth commands', () => {
    assertRegistered(p, 'login');
    assertRegistered(p, 'set-token');
    assertRegistered(p, 'whoami');
    assertRegistered(p, 'logout');
    assertRegistered(p, 'debug');
  });
});
