import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  canManageChildFeaturesFromLinks,
  isPrimaryParentExclusive,
} from './roles.js';

describe('canManageChildFeaturesFromLinks', () => {
  it('allows primary parent regardless of guardian link', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: true,
        activeGuardianAccess: null,
      }),
      true,
    );
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: true,
        activeGuardianAccess: 'view',
      }),
      true,
    );
  });

  it('allows active co_parent guardians', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'co_parent',
      }),
      true,
    );
  });

  it('denies view-tier guardians', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'view',
      }),
      false,
    );
  });

  it('denies users with no parent or guardian link', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: null,
      }),
      false,
    );
  });
});

describe('isPrimaryParentExclusive', () => {
  it('only primary parent may delete child / relink / transfer ownership', () => {
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: true }), true);
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: false }), false);
  });
});
