import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveHomeByAlertParentId } from './homeByAlertParent.js';

describe('resolveHomeByAlertParentId', () => {
  it('keeps the primary parent as alert recipient when a co-parent saves', () => {
    const primaryId = '11111111-1111-1111-1111-111111111111';
    const coParentId = '22222222-2222-2222-2222-222222222222';
    assert.equal(
      resolveHomeByAlertParentId({
        primaryParentId: primaryId,
        actorId: coParentId,
      }),
      primaryId,
    );
  });

  it('uses the actor when they are the primary parent', () => {
    const primaryId = '11111111-1111-1111-1111-111111111111';
    assert.equal(
      resolveHomeByAlertParentId({
        primaryParentId: primaryId,
        actorId: primaryId,
      }),
      primaryId,
    );
  });

  it('falls back to the actor if no primary link exists', () => {
    const actorId = '33333333-3333-3333-3333-333333333333';
    assert.equal(
      resolveHomeByAlertParentId({
        primaryParentId: null,
        actorId,
      }),
      actorId,
    );
    assert.equal(
      resolveHomeByAlertParentId({
        primaryParentId: undefined,
        actorId,
      }),
      actorId,
    );
  });
});
