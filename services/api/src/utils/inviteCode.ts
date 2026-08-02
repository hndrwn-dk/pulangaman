/** Shared invite-code normalization for child + guardian invites. */
export function normalizeInviteCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

/** True when a normalized invite code has a plausible length. */
export function isValidInviteCodeLength(code: string): boolean {
  return code.length >= 4 && code.length <= 12;
}
