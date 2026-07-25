import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './mfa.js';

describe('mfa', () => {
  const p = makeProgram();
  register(p);

  it('registers mfa commands', () => {
    assertRegistered(p, 'mfa');
    assertRegistered(p, 'mfa setup');
    assertRegistered(p, 'mfa verify');
    assertRegistered(p, 'mfa verify-code');
    assertRegistered(p, 'mfa disable');
    assertRegistered(p, 'mfa backup-codes');
  });
});
