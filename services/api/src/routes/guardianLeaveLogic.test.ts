import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  guardianLeaveAuditAction,
  guardianStatusAfterLeave,
} from './guardianLeaveLogic.js';

describe('guardianStatusAfterLeave', () => {
  it('leave revokes invited and active links immediately', () => {
    assert.equal(guardianStatusAfterLeave('leave', 'active'), 'revoked');
    assert.equal(guardianStatusAfterLeave('leave', 'invited'), 'revoked');
  });

  it('leave-request does not change status (stays active until parent revoke)', () => {
    assert.equal(guardianStatusAfterLeave('leave-request', 'active'), 'active');
    assert.equal(guardianStatusAfterLeave('leave-request', 'invited'), 'invited');
  });
});

describe('guardianLeaveAuditAction', () => {
  it('uses distinct audit actions for leave vs leave-request', () => {
    assert.equal(guardianLeaveAuditAction('leave'), 'guardian.left');
    assert.equal(guardianLeaveAuditAction('leave-request'), 'guardian.leave_requested');
  });
});
