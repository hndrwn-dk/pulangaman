import { pool } from '../db/pool.js';

export async function isParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (result.rowCount ?? 0) > 0;
}

export async function hasRole(userId: string, roles: string[]): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = ANY($2::user_role[])`,
    [userId, roles],
  );
  return (result.rowCount ?? 0) > 0;
}
