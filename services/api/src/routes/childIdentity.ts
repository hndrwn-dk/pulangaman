import { randomUUID } from 'node:crypto';

/** Server-minted, unguessable child Firebase UID (matches invite-join pattern). */
export function mintChildFirebaseUid(): string {
  return `child_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
}

/**
 * Firebase Auth phone for a child account.
 *
 * Always undefined. Children authenticate with custom tokens, not phone OTP.
 * Binding a real E.164 contact phone to the child Firebase user lets anyone
 * who completes phone OTP for that number authenticate as the child UID
 * (Firebase phone numbers are unique per project), then claim parent/guardian
 * roles on the child Postgres row via /auth/session.
 */
export function childFirebaseAuthPhone(_contactPhone?: string): undefined {
  return undefined;
}
