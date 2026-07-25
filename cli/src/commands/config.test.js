import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './config.js';

describe('config', () => {
  const p = makeProgram();
  register(p);

  it('registers config commands', () => {
    assertRegistered(p, 'config');
    assertRegistered(p, 'config set-env');
    assertRegistered(p, 'config set');
    assertRegistered(p, 'config get');
    assertRegistered(p, 'config list');
    assertRegistered(p, 'config unset');
    assertRegistered(p, 'config path');
  });
});
