import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { mintChildFirebaseUid } from './childIdentity.js';

describe('mintChildFirebaseUid', () => {
  it('mints unguessable child_* UIDs (not phone-derived)', () => {
    const phoneDigits = '6281234567890';
    const a = mintChildFirebaseUid();
    const b = mintChildFirebaseUid();
    assert.match(a, /^child_[a-f0-9]{16}$/);
    assert.match(b, /^child_[a-f0-9]{16}$/);
    assert.notEqual(a, b);
    assert.notEqual(a, `child_${phoneDigits}`);
    assert.notEqual(b, `child_${phoneDigits}`);
  });
});

describe('child create identity hijack policy', () => {
  it('client-supplied or phone-derived UIDs are never selected as the minted identity', () => {
    const attackInputs = [
      'victim_firebase_uid_abc',
      'child_6289990009999',
      'parent_6281110001111',
    ];
    for (let i = 0; i < 20; i += 1) {
      const minted = mintChildFirebaseUid();
      for (const attack of attackInputs) {
        assert.notEqual(minted, attack);
      }
      // Server mint is random hex, not equal to a phone digit string.
      assert.doesNotMatch(minted, /^child_\d+$/);
    }
  });
});
