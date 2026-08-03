import { randomUUID } from 'node:crypto';

/** Server-minted, unguessable child Firebase UID (matches invite-join pattern). */
export function mintChildFirebaseUid(): string {
  return `child_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
}
