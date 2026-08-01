import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { checkAndCelebrateStreak } from '../services/streakCelebration.js';

export const telemetryRouter = Router();
telemetryRouter.use(requireAuth, rateLimit);

telemetryRouter.post('/batch', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    const body = z
      .object({
        installationId: z.string().min(8).max(200),
        events: z
          .array(
            z.object({
              clientEventId: z.string().min(8).max(200),
              kind: z.enum(['usage', 'blocked', 'override', 'usage_hourly']),
              packageName: z.string().max(200).optional(),
              durationSeconds: z.number().int().min(0).max(86400).optional(),
              recordedAt: z.string().datetime(),
              payload: z.record(z.unknown()).optional(),
            }),
          )
          .max(500),
      })
      .parse(req.body);
    if (!childId) {
      res.status(403).json({ error: 'child_profile_required' });
      return;
    }
    const childRole = await pool.query(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
      [childId],
    );
    if (childRole.rowCount === 0) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }

    let device = await pool.query<{ id: string }>(
      `SELECT id FROM child_devices
       WHERE child_id = $1 AND installation_id = $2`,
      [childId, body.installationId],
    );
    if (device.rowCount === 0) {
      device = await pool.query<{ id: string }>(
        `INSERT INTO child_devices
           (child_id, installation_id, device_name, app_version)
         VALUES ($1, $2, 'Android child device', '0.3.0')
         ON CONFLICT (installation_id) DO UPDATE SET
           child_id = EXCLUDED.child_id,
           last_seen_at = now()
         RETURNING id`,
        [childId, body.installationId],
      );
    }
    if (device.rowCount === 0) {
      res.status(404).json({ error: 'device_not_found' });
      return;
    }

    let accepted = 0;
    for (const event of body.events) {
      await pool.query(
        `INSERT INTO usage_telemetry
           (child_id, device_id, client_event_id, kind, package_name,
            duration_seconds, recorded_at, payload)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
         ON CONFLICT (child_id, client_event_id) DO UPDATE
           SET duration_seconds = EXCLUDED.duration_seconds,
               recorded_at = EXCLUDED.recorded_at,
               payload = EXCLUDED.payload,
               kind = EXCLUDED.kind,
               package_name = EXCLUDED.package_name`,
        [
          childId,
          device.rows[0].id,
          event.clientEventId,
          event.kind,
          event.packageName ?? null,
          event.durationSeconds ?? null,
          event.recordedAt,
          JSON.stringify(event.payload ?? {}),
        ],
      );
      accepted += 1;
    }
    await pool.query(
      `UPDATE child_devices SET last_seen_at = now() WHERE id = $1`,
      [device.rows[0].id],
    );

    // Under-limit streak milestones — fire after usage lands (idempotent).
    let streakCelebration: Awaited<ReturnType<typeof checkAndCelebrateStreak>> =
      null;
    if (accepted > 0) {
      try {
        streakCelebration = await checkAndCelebrateStreak(childId);
      } catch (err) {
        console.error('streak_celebration_check_failed', childId, err);
      }
    }

    res.status(202).json({
      accepted,
      received: body.events.length,
      streakCelebration: streakCelebration
        ? {
            id: streakCelebration.id,
            milestoneDays: streakCelebration.milestoneDays,
            pointsAwarded: streakCelebration.pointsAwarded,
            accent: streakCelebration.accent,
            titleId: streakCelebration.titleId,
            bodyId: streakCelebration.bodyId,
            titleEn: streakCelebration.titleEn,
            bodyEn: streakCelebration.bodyEn,
          }
        : null,
    });
  } catch (error) {
    next(error);
  }
});

type AppsAggRow = {
  package_name: string | null;
  app_label: string | null;
  duration_seconds: number;
  blocked_count: number;
};

function mapAppsRows(rows: AppsAggRow[]) {
  return rows.map((row) => ({
    package_name: row.package_name,
    app_label: row.app_label,
    duration_seconds: Number(row.duration_seconds) || 0,
    blocked_count: Number(row.blocked_count) || 0,
  }));
}

/**
 * Parent usage summary for today / this week / this month (Jakarta calendar).
 * Query: ?period=today|week|month (default today).
 * For week/month also returns priorApps for the immediately preceding period.
 */
telemetryRouter.get('/:childId/summary', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'parent_profile_required' });
      return;
    }
    const link = await pool.query(
      `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
      [parentId, childId],
    );
    if (link.rowCount === 0) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }

    const periodRaw = typeof req.query.period === 'string' ? req.query.period : 'today';
    const period = z.enum(['today', 'week', 'month']).catch('today').parse(periodRaw);

    // Jakarta day start as timestamptz; ranges are [start, end).
    const rangeSql =
      period === 'today'
        ? {
            currentStart: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')`,
            currentEnd: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') + interval '1 day'`,
            priorStart: null as string | null,
            priorEnd: null as string | null,
          }
        : period === 'week'
          ? {
              currentStart: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') - interval '6 days'`,
              currentEnd: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') + interval '1 day'`,
              priorStart: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') - interval '13 days'`,
              priorEnd: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') - interval '6 days'`,
            }
          : {
              // Calendar month (1st → tomorrow) vs prior calendar month.
              currentStart: `(date_trunc('month', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')`,
              currentEnd: `(date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') + interval '1 day'`,
              priorStart: `(date_trunc('month', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta') - interval '1 month'`,
              priorEnd: `(date_trunc('month', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')`,
            };

    const appsQuery = `
      SELECT package_name,
             MAX(payload->>'appLabel') AS app_label,
             SUM(COALESCE(duration_seconds, 0))::integer AS duration_seconds,
             COUNT(*) FILTER (WHERE kind = 'blocked')::integer AS blocked_count
      FROM usage_telemetry
      WHERE child_id = $1
        AND kind = 'usage'
        AND recorded_at >= ${rangeSql.currentStart}
        AND recorded_at < ${rangeSql.currentEnd}
      GROUP BY package_name
      ORDER BY duration_seconds DESC`;

    const result = await pool.query<AppsAggRow>(appsQuery, [childId]);

    let priorApps: ReturnType<typeof mapAppsRows> | undefined;
    if (rangeSql.priorStart && rangeSql.priorEnd) {
      const prior = await pool.query<AppsAggRow>(
        `SELECT package_name,
                MAX(payload->>'appLabel') AS app_label,
                SUM(COALESCE(duration_seconds, 0))::integer AS duration_seconds,
                COUNT(*) FILTER (WHERE kind = 'blocked')::integer AS blocked_count
         FROM usage_telemetry
         WHERE child_id = $1
           AND kind = 'usage'
           AND recorded_at >= ${rangeSql.priorStart}
           AND recorded_at < ${rangeSql.priorEnd}
         GROUP BY package_name
         ORDER BY duration_seconds DESC`,
        [childId],
      );
      priorApps = mapAppsRows(prior.rows);
    }

    res.json({
      period,
      apps: mapAppsRows(result.rows),
      ...(priorApps ? { priorApps } : {}),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * Daily totals for the last N Jakarta calendar days (seconds per day).
 * Query: ?days=7 (default) … max 42 for month heatmap (~5 weeks).
 */
telemetryRouter.get('/:childId/weekly', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'parent_profile_required' });
      return;
    }
    const link = await pool.query(
      `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
      [parentId, childId],
    );
    if (link.rowCount === 0) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }

    const daysRaw = typeof req.query.days === 'string' ? Number(req.query.days) : 7;
    const dayCount = Number.isFinite(daysRaw)
      ? Math.min(42, Math.max(1, Math.floor(daysRaw)))
      : 7;
    const offsetDays = dayCount - 1;

    const result = await pool.query(
      `WITH days AS (
         SELECT generate_series(
           (date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')
             - ($2::int * interval '1 day'),
           date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta',
           interval '1 day'
         ) AS day_start
       )
       SELECT to_char(d.day_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD') AS day,
              COALESCE(SUM(t.duration_seconds), 0)::integer AS total_seconds
       FROM days d
       LEFT JOIN usage_telemetry t
         ON t.child_id = $1
        AND t.kind = 'usage'
        AND t.recorded_at >= d.day_start
        AND t.recorded_at < d.day_start + interval '1 day'
       GROUP BY d.day_start
       ORDER BY d.day_start`,
      [childId, offsetDays],
    );
    res.json({
      days: result.rows.map((row) => ({
        day: row.day,
        totalSeconds: Number(row.total_seconds) || 0,
      })),
    });
  } catch (error) {
    next(error);
  }
});
