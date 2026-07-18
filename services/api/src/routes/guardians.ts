import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const guardiansRouter = Router();

guardiansRouter.use(requireAuth);

const inviteSchema = z.object({
  childId: z.string().uuid(),
  guardianPhone: z.string().min(8).max(20),
  guardianName: z.string().min(1).max(120),
});

guardiansRouter.post('/invite', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = inviteSchema.parse(req.body);
    const link = await pool.query(
      `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
      [parentId, body.childId],
    );
    if (link.rowCount === 0) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      let guardianId: string;
      const existing = await client.query<{ id: string }>(
        `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
        [body.guardianPhone],
      );

      if (existing.rowCount && existing.rows[0]) {
        guardianId = existing.rows[0].id;
      } else {
        const created = await client.query<{ id: string }>(
          `INSERT INTO users (firebase_uid, phone, name)
           VALUES ($1, $2, $3)
           RETURNING id`,
          [`pending:${body.guardianPhone}`, body.guardianPhone, body.guardianName],
        );
        guardianId = created.rows[0].id;
      }

      await client.query(
        `INSERT INTO user_roles (user_id, role)
         VALUES ($1, 'guardian')
         ON CONFLICT DO NOTHING`,
        [guardianId],
      );
      await client.query(
        `INSERT INTO guardian_profiles (user_id)
         VALUES ($1)
         ON CONFLICT DO NOTHING`,
        [guardianId],
      );
      await client.query(
        `INSERT INTO child_approved_guardians
           (child_id, guardian_id, approved_by_parent_id, status)
         VALUES ($1, $2, $3, 'invited')
         ON CONFLICT (child_id, guardian_id) DO UPDATE
           SET status = 'invited',
               approved_by_parent_id = EXCLUDED.approved_by_parent_id,
               updated_at = now()`,
        [body.childId, guardianId, parentId],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'guardian.invited', $3::jsonb)`,
        [parentId, body.childId, JSON.stringify({ guardianId })],
      );

      await client.query('COMMIT');
      res.status(201).json({ guardianId, status: 'invited' });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

guardiansRouter.post('/accept', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    const childId = z.object({ childId: z.string().uuid() }).parse(req.body).childId;
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `UPDATE child_approved_guardians
       SET status = 'active', updated_at = now()
       WHERE child_id = $1 AND guardian_id = $2 AND status = 'invited'
       RETURNING child_id, guardian_id, status`,
      [childId, guardianId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'invite_not_found' });
      return;
    }

    await pool.query(
      `UPDATE guardian_profiles SET status = 'active' WHERE user_id = $1`,
      [guardianId],
    );

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

guardiansRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.query.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const link = await pool.query(
      `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
      [parentId, childId],
    );
    if (link.rowCount === 0) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const result = await pool.query(
      `SELECT cag.guardian_id, cag.status, u.name, u.phone, gp.status AS guardian_status
       FROM child_approved_guardians cag
       JOIN users u ON u.id = cag.guardian_id
       LEFT JOIN guardian_profiles gp ON gp.user_id = cag.guardian_id
       WHERE cag.child_id = $1
       ORDER BY cag.created_at`,
      [childId],
    );

    res.json({ guardians: result.rows });
  } catch (error) {
    next(error);
  }
});
