import { describe, it } from 'node:test';
import assert from 'node:assert';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './health.js';

describe('health', () => {
  it('registers health command', () => {
    const p = makeProgram();
    register(p);
    assertRegistered(p, 'health');
  });
});
