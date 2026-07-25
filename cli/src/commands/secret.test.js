import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './secret.js';

describe('secret', () => {
  const p = makeProgram();
  register(p);

  it('registers secret commands', () => {
    assertRegistered(p, 'secret');
    assertRegistered(p, 'secret list');
    assertRegistered(p, 'secret create');
    assertRegistered(p, 'secret delete');
    assertRegistered(p, 'secret resolve');
  });
});
