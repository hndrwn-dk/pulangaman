import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { config } from '../config.js';
import {
  canCreateCommunityReport,
  canModerateCommunityReport,
  publicReportPayload,
  snapReportCoord,
  type ReportRow,
} from './reportsLogic.js';

export const reportsRouter = Router();

reportsRouter.use(requireAuth, rateLimit);

const reportSchema = z.object({
  category: z.enum(['hazard', 'traffic', 'crowd', 'other']).default('hazard'),
  note: z.string().max(500).optional(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

const flagSchema = z.object({
  reason: z.string().max(200).optional(),
});

async function userRoles(userId: string): Promise<string[]> {
  const roles = await pool.query<{ role: string }>(
    `SELECT role FROM user_roles WHERE user_id = $1`,
    [userId],
  );
  return roles.rows.map((row) => row.role);
}

reportsRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const roles = await userRoles(userId);
    if (!canCreateCommunityReport(roles)) {
      res.status(403).json({ error: 'report_role_required' });
      return;
    }

    const body = reportSchema.parse(req.body);
    const lat = snapReportCoord(body.lat);
    const lng = snapReportCoord(body.lng);
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
      [userId, body.category, body.note ?? null, lng, lat, expiresAt],
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
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    await pool.query(
      `UPDATE community_reports
       SET status = 'expired'
       WHERE status = 'active'
         AND expires_at < now()`,
    );

    const result = await pool.query<ReportRow>(
      `SELECT id, category, note, status, expires_at, created_at, verified_at,
              ST_Y(location::geometry) AS lat,
              ST_X(location::geometry) AS lng
       FROM community_reports
       WHERE status IN ('active', 'verified')
         AND (status = 'verified' OR expires_at > now())
         AND NOT EXISTS (
           SELECT 1 FROM community_report_hides h
           WHERE h.report_id = community_reports.id AND h.user_id = $1
         )
       ORDER BY created_at DESC
       LIMIT 200`,
      [userId],
    );

    res.json({ reports: result.rows.map(publicReportPayload) });
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

    const roles = await userRoles(userId);
    if (!canModerateCommunityReport(roles)) {
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

reportsRouter.post('/:id/flag', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const reportId = String(req.params.id);
    const body = flagSchema.parse(req.body ?? {});
    const existing = await pool.query(
      `SELECT id FROM community_reports
       WHERE id = $1 AND status IN ('active', 'verified')`,
      [reportId],
    );
    if (existing.rowCount === 0) {
      res.status(404).json({ error: 'report_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO community_report_flags (report_id, user_id, reason)
       VALUES ($1, $2, $3)
       ON CONFLICT (report_id, user_id) DO UPDATE SET reason = EXCLUDED.reason`,
      [reportId, userId, body.reason ?? null],
    );
    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'report.flagged', $2::jsonb)`,
      [userId, JSON.stringify({ reportId })],
    );

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

reportsRouter.post('/:id/hide', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const reportId = String(req.params.id);
    const existing = await pool.query(
      `SELECT id FROM community_reports WHERE id = $1`,
      [reportId],
    );
    if (existing.rowCount === 0) {
      res.status(404).json({ error: 'report_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO community_report_hides (report_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (report_id, user_id) DO NOTHING`,
      [reportId, userId],
    );

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

reportsRouter.post('/:id/remove', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const roles = await userRoles(userId);
    if (!canModerateCommunityReport(roles)) {
      res.status(403).json({ error: 'remove_role_required' });
      return;
    }

    const reportId = String(req.params.id);
    const result = await pool.query(
      `UPDATE community_reports
       SET status = 'removed'
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
       VALUES ($1, 'report.removed', $2::jsonb)`,
      [userId, JSON.stringify({ reportId })],
    );

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});
