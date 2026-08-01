import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { canManageChildFeatures } from '../middleware/roles.js';

export const zonesRouter = Router();

zonesRouter.use(requireAuth, rateLimit);

const zoneSchema = z.object({
  childId: z.string().uuid(),
  type: z.enum(['home', 'school', 'custom']),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  radiusM: z.number().int().min(20).max(5000),
  name: z.string().max(120).optional(),
});

zonesRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = zoneSchema.parse(req.body);
    if (!(await canManageChildFeatures(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    // One home / one school per child — replace previous.
    if (body.type === 'home' || body.type === 'school') {
      const old = await pool.query<{ id: string }>(
        `SELECT id FROM zones WHERE child_id = $1 AND type = $2`,
        [body.childId, body.type],
      );
      for (const row of old.rows) {
        await pool.query(`DELETE FROM zone_states WHERE zone_id = $1`, [row.id]);
        await pool.query(`DELETE FROM zones WHERE id = $1`, [row.id]);
      }
    }

    const result = await pool.query<{ id: string }>(
      `INSERT INTO zones (child_id, type, center, radius_m, name)
       VALUES (
         $1,
         $2,
         ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
         $5,
         $6
       )
       RETURNING id`,
      [body.childId, body.type, body.lng, body.lat, body.radiusM, body.name ?? null],
    );

    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});

zonesRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    let childId: string;
    if (typeof req.query.childId === 'string' && req.query.childId.length > 0) {
      childId = z.string().uuid().parse(req.query.childId);
      if (childId !== userId) {
        if (!(await canManageChildFeatures(userId, childId))) {
          res.status(404).json({ error: 'child_not_found' });
          return;
        }
      }
    } else {
      // Child listing own zones.
      const role = await pool.query(
        `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
        [userId],
      );
      if ((role.rowCount ?? 0) === 0) {
        res.status(400).json({ error: 'child_id_required' });
        return;
      }
      childId = userId;
    }

    const result = await pool.query(
      `SELECT id, child_id, type, radius_m, name,
              ST_Y(center::geometry) AS lat,
              ST_X(center::geometry) AS lng
       FROM zones
       WHERE child_id = $1
       ORDER BY
         CASE type
           WHEN 'home' THEN 0
           WHEN 'school' THEN 1
           ELSE 2
         END,
         created_at`,
      [childId],
    );

    res.json({ zones: result.rows });
  } catch (error) {
    next(error);
  }
});

zonesRouter.delete('/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const zoneId = z.string().uuid().parse(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const zone = await pool.query<{ child_id: string }>(
      `SELECT child_id FROM zones WHERE id = $1`,
      [zoneId],
    );
    if (zone.rowCount === 0) {
      res.status(404).json({ error: 'zone_not_found' });
      return;
    }
    if (!(await canManageChildFeatures(parentId, zone.rows[0].child_id))) {
      res.status(404).json({ error: 'zone_not_found' });
      return;
    }

    await pool.query(`DELETE FROM zone_states WHERE zone_id = $1`, [zoneId]);
    await pool.query(`DELETE FROM zones WHERE id = $1`, [zoneId]);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});
