/**
 * Home By FCM/WS alerts are addressed via home_by_settings.parent_id.
 * Co-parents may edit settings (canManageChildFeatures) but must not become
 * the alert recipient — that stays with the exclusive primary parent.
 */
export function resolveHomeByAlertParentId(input: {
  primaryParentId: string | null | undefined;
  actorId: string;
}): string {
  return input.primaryParentId || input.actorId;
}
