import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { config } from '../config.js';

export const reportsRouter = Router();

reportsRouter.use(requireAuth, rateLimit);

const reportSchema = z.object({
  category: z.enum(['hazard', 'traffic', 'crowd', 'other']).default('hazard'),
  note: z.string().max(500).optional(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

reportsRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = reportSchema.parse(req.body);
    const expiresAt = new Date(
      Date.now() + config.COMMUNITY_REPORT_TTL_HOURS * 3_600_000,
    ).toISOString();

    const result = await pool.query<{ id: string }>(
      `INSERT INTO community_reports (
         reporter_id, category, note, location, expires_at
       ) VALUES (
         $1, $2, $3,
         ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
         $6
       )
       RETURNING id`,
      [userId, body.category, body.note ?? null, body.lng, body.lat, expiresAt],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'report.created', $2::jsonb)`,
      [userId, JSON.stringify({ reportId: result.rows[0].id })],
    );

    res.status(201).json({ id: result.rows[0].id, expiresAt });
  } catch (error) {
    next(error);
  }
});

reportsRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    if (!req.auth?.userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // Expire stale unverified pins.
    await pool.query(
      `UPDATE community_reports
       SET status = 'expired'
       WHERE status = 'active'
         AND expires_at < now()`,
    );

    const result = await pool.query(
      `SELECT id, category, note, status, expires_at, created_at, verified_at,
              ST_Y(location::geometry) AS lat,
              ST_X(location::geometry) AS lng
       FROM community_reports
       WHERE status IN ('active', 'verified')
         AND (status = 'verified' OR expires_at > now())
       ORDER BY created_at DESC
       LIMIT 200`,
    );

    res.json({ reports: result.rows });
  } catch (error) {
    next(error);
  }
});

reportsRouter.post('/:id/verify', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // School admins or parents may verify (light trust model for Phase 3).
    const roles = await pool.query(
      `SELECT role FROM user_roles
       WHERE user_id = $1 AND role IN ('parent', 'school_admin')`,
      [userId],
    );
    if ((roles.rowCount ?? 0) === 0) {
      res.status(403).json({ error: 'verify_role_required' });
      return;
    }

    const reportId = String(req.params.id);
    const result = await pool.query(
      `UPDATE community_reports
       SET status = 'verified', verified_at = now()
       WHERE id = $1 AND status IN ('active', 'verified')
       RETURNING id, status`,
      [reportId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'report_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'report.verified', $2::jsonb)`,
      [userId, JSON.stringify({ reportId })],
    );

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});
