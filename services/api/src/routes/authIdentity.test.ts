import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { mayClaimFirebaseUid, resolveSessionPhone } from './authIdentity.js';

describe('resolveSessionPhone', () => {
  it('uses verified token phone and ignores a different client-supplied phone', () => {
    // Attack: valid token for +628111… while body claims victim +628999…
    const phone = resolveSessionPhone({
      tokenPhone: '+6281110001111',
      bodyPhone: '+6289990009999',
    });
    assert.equal(phone, '+6281110001111');
  });

  it('falls back to body phone only when the token has no phone (dev-auth)', () => {
    assert.equal(
      resolveSessionPhone({ bodyPhone: '+6281110001111' }),
      '+6281110001111',
    );
    assert.equal(resolveSessionPhone({ tokenPhone: '  ', bodyPhone: '+6281110001111' }), '+6281110001111');
  });

  it('returns undefined when neither token nor body provides a phone', () => {
    assert.equal(resolveSessionPhone({}), undefined);
  });
});

describe('mayClaimFirebaseUid', () => {
  it('allows claiming only pending: placeholders', () => {
    assert.equal(mayClaimFirebaseUid('pending:+6281110001111'), true);
    assert.equal(mayClaimFirebaseUid('pending:081110001111'), true);
  });

  it('refuses to rebind a real or legacy Firebase UID found by phone digits', () => {
    // Attack surface removed: matching phone must not steal these identities.
    assert.equal(mayClaimFirebaseUid('firebaseRealUidAbCdEf'), false);
    assert.equal(mayClaimFirebaseUid('parent_6281110001111'), false);
    assert.equal(mayClaimFirebaseUid('child_6289990009999'), false);
    assert.equal(mayClaimFirebaseUid('guardian_6281110001111'), false);
    assert.equal(mayClaimFirebaseUid('dev:attacker'), false);
  });
});

describe('session phone takeover policy', () => {
  it('attacker posting victim phone with own token cannot select victim identity phone', () => {
    const attackerTokenPhone = '+6281110001111';
    const victimPhone = '+6289990009999';
    const boundPhone = resolveSessionPhone({
      tokenPhone: attackerTokenPhone,
      bodyPhone: victimPhone,
    });
    assert.notEqual(boundPhone, victimPhone);
    assert.equal(boundPhone, attackerTokenPhone);
  });

  it('even if a victim row were found by phone, a real UID must not be claimable', () => {
    const victimExistingUid = 'victimFirebaseUidXYZ';
    assert.equal(mayClaimFirebaseUid(victimExistingUid), false);
  });
});
