import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './account.js';

describe('account', () => {
  const p = makeProgram();
  register(p);

  it('registers account commands', () => {
    assertRegistered(p, 'register');
    assertRegistered(p, 'verify-email');
    assertRegistered(p, 'resend-verification');
    assertRegistered(p, 'password');
    assertRegistered(p, 'password reset');
    assertRegistered(p, 'password confirm-reset');
    assertRegistered(p, 'password change');
    assertRegistered(p, 'avatar');
    assertRegistered(p, 'avatar upload');
    assertRegistered(p, 'avatar delete');
  });
});
