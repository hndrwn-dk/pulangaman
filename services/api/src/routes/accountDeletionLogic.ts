/** Pure helpers for self-account deletion policy (unit-tested without DB). */

export function selfDeletionError(roles: string[]): string | null {
  if (roles.includes('child')) {
    return 'child_deletion_requires_parent';
  }
  return null;
}

/** Parent/guardian row plus exclusively-owned primary children. */
export function accountDeletionUserIds(
  userId: string,
  primaryChildren: Array<{ id: string }>,
): string[] {
  return [userId, ...primaryChildren.map((c) => c.id)];
}
