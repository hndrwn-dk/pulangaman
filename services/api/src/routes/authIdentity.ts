/**
 * Session identity helpers — phone from the verified Firebase token is the
 * source of truth; client-supplied digits must never rebind a real account.
 */

/** Prefer token phone; allow body phone only when the token has none (dev-auth). */
export function resolveSessionPhone(input: {
  tokenPhone?: string;
  bodyPhone?: string;
}): string | undefined {
  const token = input.tokenPhone?.trim();
  if (token) return token;
  const body = input.bodyPhone?.trim();
  if (body) return body;
  return undefined;
}

/** Only `pending:{phone}` placeholders may be claimed onto a real Firebase UID. */
export function mayClaimFirebaseUid(existingUid: string): boolean {
  return existingUid.startsWith('pending:');
}
