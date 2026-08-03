/**
 * Legacy parent phone → new parent custody recovery.
 *
 * Historically any authenticated parent could POST recoverFromPhone with a
 * victim's legacy phone and steal parent_children links when the victim row
 * still had a synthetic firebase_uid (parent_*, dev:*, …). There is no proof
 * that the caller controls that prior number, so cross-phone recovery is
 * refused until a verified second factor exists.
 */

export function allowLegacyChildRecovery(input: {
  actorPhoneDigits: string;
  recoverFromPhoneDigits: string;
  legacyFirebaseUid: string;
}): boolean {
  void input;
  return false;
}

export function isLegacyFirebaseUid(uid: string): boolean {
  return (
    uid.startsWith('parent_') ||
    uid.startsWith('guardian_') ||
    uid.startsWith('child_') ||
    uid.startsWith('dev:') ||
    uid.startsWith('pending:')
  );
}
