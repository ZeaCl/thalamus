import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './doctor.js';

describe('doctor', () => {
  const p = makeProgram();
  register(p);

  it('registers doctor command', () => {
    assertRegistered(p, 'doctor');
  });
});
