import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { isValidInviteCodeLength, normalizeInviteCode } from './inviteCode.js';

describe('normalizeInviteCode', () => {
  it('strips spaces and uppercases', () => {
    assert.equal(normalizeInviteCode('XE6 RJ7'), 'XE6RJ7');
    assert.equal(normalizeInviteCode('xe6rj7'), 'XE6RJ7');
    assert.equal(normalizeInviteCode('  xe6-rj7  '), 'XE6RJ7');
  });

  it('removes punctuation and lowercase letters only via uppercasing', () => {
    assert.equal(normalizeInviteCode('ab.cd/ef'), 'ABCDEF');
  });
});

describe('isValidInviteCodeLength', () => {
  it('accepts normalized 6-char codes', () => {
    assert.equal(isValidInviteCodeLength('XE6RJ7'), true);
  });

  it('rejects empty or too-short after normalize', () => {
    assert.equal(isValidInviteCodeLength(''), false);
    assert.equal(isValidInviteCodeLength('AB'), false);
  });
});
