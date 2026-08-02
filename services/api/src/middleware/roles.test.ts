import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  canManageChildFeaturesFromLinks,
  canViewChildFromLinks,
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

describe('canViewChildFromLinks', () => {
  it('allows primary parent', () => {
    assert.equal(
      canViewChildFromLinks({
        isPrimaryParent: true,
        activeGuardianAccess: null,
      }),
      true,
    );
  });

  it('allows active co_parent guardians', () => {
    assert.equal(
      canViewChildFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'co_parent',
      }),
      true,
    );
  });

  it('allows active view-tier guardians', () => {
    assert.equal(
      canViewChildFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'view',
      }),
      true,
    );
  });

  it('denies users with no parent or guardian link', () => {
    assert.equal(
      canViewChildFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: null,
      }),
      false,
    );
  });
});

describe('permission matrix: manage vs view', () => {
  const cases: Array<{
    label: string;
    isPrimaryParent: boolean;
    activeGuardianAccess: 'view' | 'co_parent' | null;
    canManage: boolean;
    canView: boolean;
  }> = [
    {
      label: 'primary parent',
      isPrimaryParent: true,
      activeGuardianAccess: null,
      canManage: true,
      canView: true,
    },
    {
      label: 'co_parent guardian',
      isPrimaryParent: false,
      activeGuardianAccess: 'co_parent',
      canManage: true,
      canView: true,
    },
    {
      label: 'view guardian',
      isPrimaryParent: false,
      activeGuardianAccess: 'view',
      canManage: false,
      canView: true,
    },
    {
      label: 'unlinked user',
      isPrimaryParent: false,
      activeGuardianAccess: null,
      canManage: false,
      canView: false,
    },
  ];

  for (const c of cases) {
    it(`${c.label}: manage=${c.canManage} view=${c.canView}`, () => {
      const input = {
        isPrimaryParent: c.isPrimaryParent,
        activeGuardianAccess: c.activeGuardianAccess,
      };
      assert.equal(canManageChildFeaturesFromLinks(input), c.canManage);
      assert.equal(canViewChildFromLinks(input), c.canView);
    });
  }
});

describe('isPrimaryParentExclusive', () => {
  it('only primary parent may delete child / relink / transfer ownership', () => {
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: true }), true);
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: false }), false);
  });

  it('guardian invite / promote / revoke follow the same primary-only rule', () => {
    // Co-parents keep canManage for zones/EMP/reminders/home-by, but must not
    // create invites, change access levels, or revoke guardians.
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: true }), true);
    assert.equal(isPrimaryParentExclusive({ isPrimaryParent: false }), false);
    assert.equal(
      canManageChildFeaturesFromLinks({
        isPrimaryParent: false,
        activeGuardianAccess: 'co_parent',
      }),
      true,
      'co_parent still manages features',
    );
  });
});
