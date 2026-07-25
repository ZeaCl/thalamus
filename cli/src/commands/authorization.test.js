import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './authorization.js';

describe('authorization', () => {
  const p = makeProgram();
  register(p);

  it('registers authorization validate-step', () => {
    assertRegistered(p, 'authorization');
    assertRegistered(p, 'authorization validate-step');
  });
});
