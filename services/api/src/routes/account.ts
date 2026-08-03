import { Router } from 'express';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { hasRole, listPrimaryChildren } from '../middleware/roles.js';
import { deleteFirebaseUser } from '../firebase/admin.js';
import {
  accountDeletionUserIds,
  selfDeletionError,
} from './accountDeletionLogic.js';

export const accountRouter = Router();

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

    const primaryChildren = await listPrimaryChildren(userId);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

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
