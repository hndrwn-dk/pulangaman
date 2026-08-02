import { config } from '../config.js';

type Attempt = { failures: number; windowStart: number; lockedUntil: number | null };
const attempts = new Map<string, Attempt>();

export function isInviteLocked(key: string): boolean {
  const entry = attempts.get(key);
  if (!entry?.lockedUntil) return false;
  if (Date.now() >= entry.lockedUntil) {
    attempts.delete(key);
    return false;
  }
  return true;
}

export function recordInviteFailure(key: string): void {
  const now = Date.now();
  let entry = attempts.get(key);
  if (!entry || now - entry.windowStart > config.INVITE_ATTEMPT_WINDOW_MS) {
    entry = { failures: 0, windowStart: now, lockedUntil: null };
  }
  entry.failures += 1;
  if (entry.failures >= config.INVITE_ATTEMPT_MAX) {
    entry.lockedUntil = now + config.INVITE_ATTEMPT_LOCKOUT_MS;
  }
  attempts.set(key, entry);
}

export function clearInviteAttempts(key: string): void {
  attempts.delete(key);
}

/** Clears all attempt state — for tests only. */
export function resetInviteAttemptsForTests(): void {
  attempts.clear();
}
