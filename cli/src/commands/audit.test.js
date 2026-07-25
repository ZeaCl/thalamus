import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './audit.js';

describe('audit', () => {
  const p = makeProgram();
  register(p);

  it('registers audit + oidc commands', () => {
    assertRegistered(p, 'audit');
    assertRegistered(p, 'audit export');
    assertRegistered(p, 'oidc');
    assertRegistered(p, 'oidc discovery');
    assertRegistered(p, 'oidc jwks');
  });
});
