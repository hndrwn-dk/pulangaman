import { Router } from 'express';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { hasRole } from '../middleware/roles.js';
import { deleteFirebaseUser } from '../firebase/admin.js';
import { deleteChildLocationCache } from '../redis/client.js';
import {
  accountDeletionUserIds,
  selfDeletionError,
} from './accountDeletionLogic.js';

export const accountRouter = Router();

accountRouter.get('/watchers', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const isChild = await hasRole(userId, ['child']);
    if (!isChild) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }

    const result = await pool.query<{ name: string; kind: 'parent' | 'guardian' }>(
      `SELECT u.name, 'parent'::text AS kind
       FROM parent_children pc
       JOIN users u ON u.id = pc.parent_id
       WHERE pc.child_id = $1
       UNION
       SELECT u.name, 'guardian'::text AS kind
       FROM child_approved_guardians cag
       JOIN users u ON u.id = cag.guardian_id
       WHERE cag.child_id = $1 AND cag.status = 'active'
       ORDER BY kind, name`,
      [userId],
    );

    res.json({
      watchers: result.rows.map((row) => ({
        name: row.name,
        kind: row.kind,
      })),
    });
  } catch (error) {
    next(error);
  }
});

accountRouter.delete('/', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // Children don't self-delete — account is parent-managed. Ask a
    // parent to remove them (see /children/:id/data below) or delete
    // the parent account, which cascades to any exclusively-owned child.
    const isChild = await hasRole(userId, ['child']);
    const blocked = selfDeletionError(isChild ? ['child'] : []);
    if (blocked) {
      res.status(403).json({ error: blocked });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Lock the parent row first so a concurrent INSERT into
      // parent_children (FK takes FOR KEY SHARE on users) waits until
      // this transaction finishes, instead of linking a child that
      // CASCADE would then orphan when the parent row is deleted.
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);

      const primaryChildrenResult = await client.query<{ id: string; name: string }>(
        `SELECT u.id, u.name
         FROM parent_children pc
         JOIN users u ON u.id = pc.child_id
         WHERE pc.parent_id = $1
         ORDER BY u.name
         FOR UPDATE OF u`,
        [userId],
      );
      const primaryChildren = primaryChildrenResult.rows;

      const idsToDelete = accountDeletionUserIds(userId, primaryChildren);
      const uidRows = await client.query<{ firebase_uid: string }>(
        `SELECT firebase_uid FROM users WHERE id = ANY($1::uuid[])`,
        [idsToDelete],
      );

      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, NULL, 'account.self_deleted',
                 jsonb_build_object('cascadedChildren', $2::int))`,
        [userId, primaryChildren.length],
      );

      // Exclusively-owned children first — deleting a parent row does
      // NOT cascade to children (parent_children.child_id CASCADE only
      // fires the other direction), so this step is required. Deleting
      // each child row DOES cascade through location_history, zones,
      // devices, screentime, EMP, child_approved_guardians, etc.
      for (const child of primaryChildren) {
        await client.query('DELETE FROM users WHERE id = $1', [child.id]);
      }
      await client.query('DELETE FROM users WHERE id = $1', [userId]);

      await client.query('COMMIT');

      for (const child of primaryChildren) {
        await deleteChildLocationCache(child.id);
      }
      for (const row of uidRows.rows) {
        await deleteFirebaseUser(row.firebase_uid);
      }

      res.status(204).send();
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});
