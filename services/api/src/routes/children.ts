import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { childLocationKey, getRedis } from '../redis/client.js';
import { config } from '../config.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const childrenRouter = Router();

childrenRouter.use(requireAuth);

const createChildSchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20),
  firebaseUid: z.string().min(1),
  grade: z.number().int().min(1).max(12).optional(),
});

childrenRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = createChildSchema.parse(req.body);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const child = await client.query<{ id: string }>(
        `INSERT INTO users (firebase_uid, phone, name)
         VALUES ($1, $2, $3)
         RETURNING id`,
        [body.firebaseUid, body.phone, body.name],
      );
      const childId = child.rows[0].id;

      await client.query(
        `INSERT INTO user_roles (user_id, role) VALUES ($1, 'child')`,
        [childId],
      );
      await client.query(
        `INSERT INTO child_profiles (user_id, grade) VALUES ($1, $2)`,
        [childId, body.grade ?? null],
      );
      await client.query(
        `INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)`,
        [parentId, childId],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'child.created', '{}'::jsonb)`,
        [parentId, childId],
      );

      await client.query('COMMIT');
      res.status(201).json({ id: childId, name: body.name });
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

childrenRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `SELECT u.id, u.name, u.phone, cp.grade, cp.commute_status, cp.last_seen_at
       FROM parent_children pc
       JOIN users u ON u.id = pc.child_id
       LEFT JOIN child_profiles cp ON cp.user_id = u.id
       WHERE pc.parent_id = $1
       ORDER BY u.name`,
      [parentId],
    );

    res.json({ children: result.rows });
  } catch (error) {
    next(error);
  }
});

childrenRouter.get('/:id/location', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = String(req.params.id);
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

    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }
    const cached = await redis.get(childLocationKey(childId));
    if (!cached) {
      res.status(404).json({ error: 'location_unavailable' });
      return;
    }

    res.json({
      childId,
      location: JSON.parse(cached),
      ttlSeconds: config.LOCATION_TTL_SECONDS,
    });
  } catch (error) {
    next(error);
  }
});
