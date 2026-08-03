/**
 * Pure helpers for guardian self-leave vs leave-request.
 * leave-request must NOT change child_approved_guardians.status —
 * access stays active until the parent uses existing /guardians/revoke.
 */

export type GuardianLeaveAction = 'leave' | 'leave-request';

export function guardianStatusAfterLeave(
  action: GuardianLeaveAction,
  currentStatus: 'invited' | 'active' | 'revoked',
): 'invited' | 'active' | 'revoked' {
  if (action === 'leave' && (currentStatus === 'invited' || currentStatus === 'active')) {
    return 'revoked';
  }
  return currentStatus;
}

export function guardianLeaveAuditAction(
  action: GuardianLeaveAction,
): 'guardian.left' | 'guardian.leave_requested' {
  return action === 'leave' ? 'guardian.left' : 'guardian.leave_requested';
}
