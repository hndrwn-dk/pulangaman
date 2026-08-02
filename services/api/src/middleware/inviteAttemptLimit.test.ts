import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { config } from '../config.js';
import {
  clearInviteAttempts,
  isInviteLocked,
  recordInviteFailure,
  resetInviteAttemptsForTests,
} from './inviteAttemptLimit.js';

describe('inviteAttemptLimit', () => {
  beforeEach(() => {
    resetInviteAttemptsForTests();
  });

  it('locks after INVITE_ATTEMPT_MAX failures from the same key', () => {
    const key = 'join:127.0.0.1';
    const max = config.INVITE_ATTEMPT_MAX;

    for (let i = 0; i < max; i += 1) {
      assert.equal(isInviteLocked(key), false);
      recordInviteFailure(key);
    }

    assert.equal(isInviteLocked(key), true);
  });

  it('allows a successful clear before the lock threshold', () => {
    const key = 'redeem:guardian-a';
    const max = config.INVITE_ATTEMPT_MAX;

    for (let i = 0; i < max - 1; i += 1) {
      recordInviteFailure(key);
    }
    assert.equal(isInviteLocked(key), false);

    // Successful redeem clears prior failures so the next attempt is not locked.
    clearInviteAttempts(key);
    assert.equal(isInviteLocked(key), false);

    for (let i = 0; i < max - 1; i += 1) {
      recordInviteFailure(key);
    }
    assert.equal(isInviteLocked(key), false);
  });

  it('does not carry lockout across keys after a successful clear', () => {
    const keyA = 'join:10.0.0.1';
    const keyB = 'join:10.0.0.2';
    const max = config.INVITE_ATTEMPT_MAX;

    for (let i = 0; i < max - 1; i += 1) {
      recordInviteFailure(keyA);
    }
    clearInviteAttempts(keyA);

    assert.equal(isInviteLocked(keyA), false);
    assert.equal(isInviteLocked(keyB), false);

    recordInviteFailure(keyB);
    assert.equal(isInviteLocked(keyB), false);
    assert.equal(isInviteLocked(keyA), false);
  });
});
