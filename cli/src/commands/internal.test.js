import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './internal.js';

describe('internal', () => {
  const p = makeProgram();
  register(p);

  it('registers internal commands', () => {
    assertRegistered(p, 'internal');
    assertRegistered(p, 'internal agent-token');
    assertRegistered(p, 'internal agent-config');
  });
});
