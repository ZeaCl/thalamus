import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './admin.js';

describe('admin', () => {
  const p = makeProgram();
  register(p);

  it('registers admin api-key commands', () => {
    assertRegistered(p, 'admin');
    assertRegistered(p, 'admin api-key');
    assertRegistered(p, 'admin api-key list');
    assertRegistered(p, 'admin api-key show');
    assertRegistered(p, 'admin api-key create');
    assertRegistered(p, 'admin api-key revoke');
    assertRegistered(p, 'admin api-key rotate');
  });
});
