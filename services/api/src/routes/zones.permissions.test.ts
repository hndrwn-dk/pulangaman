import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { canManageChildFeaturesFromLinks } from '../middleware/roles.js';

describe('view-tier cannot manage zones writes', () => {
  it('denies canManageChildFeatures for view guardians', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'view',
      }),
      false,
    );
  });

  it('allows co_parent and primary', () => {
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'co_parent',
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
});
