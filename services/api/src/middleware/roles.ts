import { pool } from '../db/pool.js';

export type GuardianAccessLevel = 'view' | 'co_parent';

/** Child access as seen by the current user (list endpoints). */
export type ChildAccess = 'primary' | 'co_parent' | 'view';

/** Pure permission rules — unit-tested without DB. */
export function canManageChildFeaturesFromLinks(input: {
  isPrimaryParent: boolean;
  /** Active guardian access level, or null when not an active guardian. */
  activeGuardianAccess: GuardianAccessLevel | null;
}): boolean {
  if (input.isPrimaryParent) return true;
  return input.activeGuardianAccess === 'co_parent';
}

/**
 * Read access for location / history / timeline / feature GET.
 * Primary parent OR any active guardian (view or co_parent).
 */
export function canViewChildFromLinks(input: {
  isPrimaryParent: boolean;
  activeGuardianAccess: GuardianAccessLevel | null;
}): boolean {
  if (input.isPrimaryParent) return true;
  return input.activeGuardianAccess !== null;
}

/** Primary parent only — delete child link, relink codes, ownership transfer. */
export function isPrimaryParentExclusive(input: {
  isPrimaryParent: boolean;
}): boolean {
  return input.isPrimaryParent;
}

export async function isParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function getActiveGuardianAccess(
  guardianId: string,
  childId: string,
): Promise<GuardianAccessLevel | null> {
  const result = await pool.query<{ access_level: GuardianAccessLevel }>(
    `SELECT access_level
     FROM child_approved_guardians
     WHERE guardian_id = $1 AND child_id = $2 AND status = 'active'`,
    [guardianId, childId],
  );
  if ((result.rowCount ?? 0) === 0) return null;
  return result.rows[0].access_level;
}

/**
 * Shared write/manage check for Safe Zones, EMP, Reminders, Safe Home Time,
 * and guardian invite/manage. Primary parent OR active co_parent guardian.
 */
export async function canManageChildFeatures(
  userId: string,
  childId: string,
): Promise<boolean> {
  const isPrimary = await isParentOfChild(userId, childId);
  if (isPrimary) return true;
  const access = await getActiveGuardianAccess(userId, childId);
  return canManageChildFeaturesFromLinks({
    isPrimaryParent: false,
    activeGuardianAccess: access,
  });
}

/**
 * Shared read check for location, history, timeline, and feature GET endpoints.
 * Primary parent OR any active guardian (view or co_parent).
 */
export async function canViewChild(
  userId: string,
  childId: string,
): Promise<boolean> {
  const isPrimary = await isParentOfChild(userId, childId);
  if (isPrimary) return true;
  const access = await getActiveGuardianAccess(userId, childId);
  return canViewChildFromLinks({
    isPrimaryParent: false,
    activeGuardianAccess: access,
  });
}

/** Children the user may manage for co-parent feature screens (zones, EMP, etc.). */
export async function listFeatureManagedChildren(userId: string): Promise<
  Array<{ id: string; name: string; phone: string | null; access: 'primary' | 'co_parent'; accessLevel: 'primary' | 'co_parent' }>
> {
  const result = await pool.query<{
    id: string;
    name: string;
    phone: string | null;
    access: 'primary' | 'co_parent';
  }>(
    `SELECT u.id, u.name, u.phone, 'primary'::text AS access
     FROM parent_children pc
     JOIN users u ON u.id = pc.child_id
     WHERE pc.parent_id = $1
     UNION
     SELECT u.id, u.name, u.phone, 'co_parent'::text AS access
     FROM child_approved_guardians cag
     JOIN users u ON u.id = cag.child_id
     WHERE cag.guardian_id = $1
       AND cag.status = 'active'
       AND cag.access_level = 'co_parent'
       AND NOT EXISTS (
         SELECT 1 FROM parent_children pc2
         WHERE pc2.parent_id = $1 AND pc2.child_id = cag.child_id
       )
     ORDER BY name`,
    [userId],
  );
  return result.rows.map((row) => ({
    ...row,
    accessLevel: row.access,
  }));
}

/**
 * Children the user may view: primary parent links plus any active guardian
 * link (view or co_parent). Prefer primary when both exist.
 */
export async function listViewableChildren(userId: string): Promise<
  Array<{
    id: string;
    name: string;
    phone: string | null;
    grade: number | null;
    commute_status: string | null;
    last_seen_at: Date | null;
    access: ChildAccess;
    accessLevel: ChildAccess;
  }>
> {
  const result = await pool.query<{
    id: string;
    name: string;
    phone: string | null;
    grade: number | null;
    commute_status: string | null;
    last_seen_at: Date | null;
    access: ChildAccess;
  }>(
    `SELECT u.id, u.name, u.phone, cp.grade, cp.commute_status, cp.last_seen_at,
            'primary'::text AS access
     FROM parent_children pc
     JOIN users u ON u.id = pc.child_id
     LEFT JOIN child_profiles cp ON cp.user_id = u.id
     WHERE pc.parent_id = $1
     UNION
     SELECT u.id, u.name, u.phone, cp.grade, cp.commute_status, cp.last_seen_at,
            cag.access_level::text AS access
     FROM child_approved_guardians cag
     JOIN users u ON u.id = cag.child_id
     LEFT JOIN child_profiles cp ON cp.user_id = u.id
     WHERE cag.guardian_id = $1
       AND cag.status = 'active'
       AND cag.access_level IN ('view', 'co_parent')
       AND NOT EXISTS (
         SELECT 1 FROM parent_children pc2
         WHERE pc2.parent_id = $1 AND pc2.child_id = cag.child_id
       )
     ORDER BY name`,
    [userId],
  );
  return result.rows.map((row) => ({
    ...row,
    accessLevel: row.access,
  }));
}

export async function hasRole(userId: string, roles: string[]): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = ANY($2::user_role[])`,
    [userId, roles],
  );
  return (result.rowCount ?? 0) > 0;
}
