import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const zonesRouter = Router();

zonesRouter.use(requireAuth);

const zoneSchema = z.object({
  childId: z.string().uuid(),
  type: z.enum(['home', 'school', 'custom']),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  radiusM: z.number().int().min(20).max(5000),
  name: z.string().max(120).optional(),
});

async function assertParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const link = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (link.rowCount ?? 0) > 0;
}

zonesRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = zoneSchema.parse(req.body);
    if (!(await assertParentOfChild(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
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
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.query.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const result = await pool.query(
      `SELECT id, child_id, type, radius_m, name,
              ST_Y(center::geometry) AS lat,
              ST_X(center::geometry) AS lng
       FROM zones
       WHERE child_id = $1
       ORDER BY created_at`,
      [childId],
    );

    res.json({ zones: result.rows });
  } catch (error) {
    next(error);
  }
});
