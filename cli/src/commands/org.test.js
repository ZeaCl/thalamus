import { describe, it } from 'node:test';
import { makeProgram, assertRegistered } from '../../test/helpers.js';
import { register } from './org.js';

describe('org', () => {
  const p = makeProgram();
  register(p);

  it('registers org commands', () => {
    assertRegistered(p, 'org');
    assertRegistered(p, 'org list');
    assertRegistered(p, 'org switch');
    assertRegistered(p, 'org create');
    assertRegistered(p, 'org show');
    assertRegistered(p, 'org update');
    assertRegistered(p, 'org delete');
    assertRegistered(p, 'org member');
    assertRegistered(p, 'org saml');
  });

  it('registers member subcommands', () => {
    assertRegistered(p, 'org member add');
    assertRegistered(p, 'org member remove');
    assertRegistered(p, 'org member list');
  });

  it('registers saml subcommands', () => {
    assertRegistered(p, 'org saml show');
    assertRegistered(p, 'org saml set');
    assertRegistered(p, 'org saml delete');
  });
});
