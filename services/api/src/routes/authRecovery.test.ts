import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  allowLegacyChildRecovery,
  isLegacyFirebaseUid,
} from './authRecovery.js';

describe('allowLegacyChildRecovery', () => {
  it('refuses cross-phone custody transfer without proof of prior number', () => {
    assert.equal(
      allowLegacyChildRecovery({
        actorPhoneDigits: '628111111111',
        recoverFromPhoneDigits: '628222222222',
        legacyFirebaseUid: 'parent_628222222222',
      }),
      false,
    );
  });

  it('refuses even when the legacy uid looks synthetic', () => {
    assert.equal(
      allowLegacyChildRecovery({
        actorPhoneDigits: '628111111111',
        recoverFromPhoneDigits: '628222222222',
        legacyFirebaseUid: 'dev:parent:628222222222',
      }),
      false,
    );
  });
});

describe('isLegacyFirebaseUid', () => {
  it('detects synthetic migration uids', () => {
    assert.equal(isLegacyFirebaseUid('parent_628123'), true);
    assert.equal(isLegacyFirebaseUid('dev:abc'), true);
    assert.equal(isLegacyFirebaseUid('pending:+628123'), true);
    assert.equal(isLegacyFirebaseUid('firebaseRealUidXYZ'), false);
  });
});
