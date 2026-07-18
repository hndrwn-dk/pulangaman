import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { childLocationKey, getRedis } from '../redis/client.js';
import { config } from '../config.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { createChildCustomToken, ensureFirebaseUser } from '../firebase/admin.js';

export const childrenRouter = Router();

childrenRouter.use(requireAuth, rateLimit);

const createChildSchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20),
  grade: z.number().int().min(1).max(12).optional(),
  /** Optional override for tests/dev; otherwise server mints a Firebase uid. */
  firebaseUid: z.string().min(1).optional(),
});

const emergencyContactSchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20),
  priority: z.number().int().min(1).max(20).default(1),
});

async function assertParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const link = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (link.rowCount ?? 0) > 0;
}

childrenRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = createChildSchema.parse(req.body);
    const normalizedPhone = body.phone.replace(/\D/g, '');
    const firebaseUid = body.firebaseUid ?? `child_${normalizedPhone}`;
    await ensureFirebaseUser({
      uid: firebaseUid,
      phone: body.phone.startsWith('+') ? body.phone : undefined,
      displayName: body.name,
    });
    const tokenResult = await createChildCustomToken(firebaseUid);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // If parent already created this phone, return existing link + fresh custom token.
      const existing = await client.query<{ id: string }>(
        `SELECT u.id
         FROM users u
         JOIN parent_children pc ON pc.child_id = u.id
         WHERE pc.parent_id = $1 AND u.phone = $2
         LIMIT 1`,
        [parentId, body.phone],
      );
      if (existing.rowCount && existing.rows[0]) {
        await client.query('COMMIT');
        res.status(200).json({
          id: existing.rows[0].id,
          name: body.name,
          firebaseUid,
          customToken: tokenResult.customToken,
        });
        return;
      }

      const child = await client.query<{ id: string }>(
        `INSERT INTO users (firebase_uid, phone, name)
         VALUES ($1, $2, $3)
         ON CONFLICT (firebase_uid) DO UPDATE
           SET name = EXCLUDED.name, phone = EXCLUDED.phone, updated_at = now()
         RETURNING id`,
        [firebaseUid, body.phone, body.name],
      );
      const childId = child.rows[0].id;

      await client.query(
        `INSERT INTO user_roles (user_id, role) VALUES ($1, 'child')
         ON CONFLICT DO NOTHING`,
        [childId],
      );
      await client.query(
        `INSERT INTO child_profiles (user_id, grade) VALUES ($1, $2)
         ON CONFLICT (user_id) DO UPDATE SET grade = COALESCE(EXCLUDED.grade, child_profiles.grade)`,
        [childId, body.grade ?? null],
      );
      await client.query(
        `INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [parentId, childId],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'child.created', '{}'::jsonb)`,
        [parentId, childId],
      );

      await client.query('COMMIT');
      res.status(201).json({
        id: childId,
        name: body.name,
        firebaseUid,
        customToken: tokenResult.customToken,
      });
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

    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }
    const cached = await redis.get(childLocationKey(childId));
    if (!cached) {
      const profile = await pool.query<{ last_seen_at: Date | null }>(
        `SELECT last_seen_at FROM child_profiles WHERE user_id = $1`,
        [childId],
      );
      res.status(404).json({
        error: 'location_unavailable',
        isStale: true,
        lastSeenAt: profile.rows[0]?.last_seen_at ?? null,
      });
      return;
    }

    const location = JSON.parse(cached) as {
      lat: number;
      lng: number;
      recordedAt?: string;
      accuracyM?: number | null;
    };
    const recordedAt = location.recordedAt ? new Date(location.recordedAt).getTime() : 0;
    const ageSeconds = recordedAt ? Math.floor((Date.now() - recordedAt) / 1000) : null;
    const isStale =
      ageSeconds === null || ageSeconds > config.STALE_LOCATION_SECONDS;

    res.json({
      childId,
      location,
      ttlSeconds: config.LOCATION_TTL_SECONDS,
      ageSeconds,
      isStale,
      staleAfterSeconds: config.STALE_LOCATION_SECONDS,
    });
  } catch (error) {
    next(error);
  }
});

childrenRouter.post('/:id/emergency-contacts', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = String(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const body = emergencyContactSchema.parse(req.body);
    const result = await pool.query<{ id: string }>(
      `INSERT INTO emergency_contacts (child_id, name, phone, priority)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [childId, body.name, body.phone, body.priority],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'emergency_contact.created', $3::jsonb)`,
      [parentId, childId, JSON.stringify({ contactId: result.rows[0].id })],
    );

    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});

childrenRouter.get('/:id/emergency-contacts', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = String(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const result = await pool.query(
      `SELECT id, name, phone, priority
       FROM emergency_contacts
       WHERE child_id = $1
       ORDER BY priority ASC`,
      [childId],
    );
    res.json({ contacts: result.rows });
  } catch (error) {
    next(error);
  }
});
