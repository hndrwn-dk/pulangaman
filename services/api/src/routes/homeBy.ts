import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { canManageChildFeatures, canViewChild } from '../middleware/roles.js';
import { applyAckForChild } from '../services/homeByService.js';
import { jakartaDateString } from '../services/homeByLogic.js';

export const homeByRouter = Router();
homeByRouter.use(requireAuth, rateLimit);

async function assertIsChild(userId: string): Promise<boolean> {
  const role = await pool.query(
    `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
    [userId],
  );
  return (role.rowCount ?? 0) > 0;
}

const putSchema = z
  .object({
    mode: z.enum(['off', 'maghrib', 'custom']),
    customHour: z.number().int().min(0).max(23).nullable().optional(),
    customMinute: z.number().int().min(0).max(59).nullable().optional(),
    gracePeriodMinutes: z.number().int().min(5).max(120).optional(),
    homeZoneId: z.string().uuid().nullable().optional(),
    weekendMode: z.enum(['off', 'same', 'custom']).optional(),
    weekendHour: z.number().int().min(0).max(23).nullable().optional(),
    weekendMinute: z.number().int().min(0).max(59).nullable().optional(),
    enabled: z.boolean().optional(),
  })
  .superRefine((body, ctx) => {
    if (body.mode === 'custom') {
      if (body.customHour == null || body.customMinute == null) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'custom_time_required',
          path: ['customHour'],
        });
      }
    }
    const weekendMode = body.weekendMode ?? 'off';
    if (weekendMode === 'custom') {
      if (body.weekendHour == null || body.weekendMinute == null) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'weekend_time_required',
          path: ['weekendHour'],
        });
      }
    }
  });

function mapSettings(row: Record<string, unknown>) {
  return {
    childId: row.child_id,
    parentId: row.parent_id,
    mode: row.mode,
    customHour: row.custom_hour,
    customMinute: row.custom_minute,
    gracePeriodMinutes: row.grace_period_minutes,
    homeZoneId: row.home_zone_id,
    weekendMode: row.weekend_mode,
    weekendHour: row.weekend_hour,
    weekendMinute: row.weekend_minute,
    enabled: row.enabled,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapEvent(row: Record<string, unknown> | undefined) {
  if (!row) return null;
  return {
    id: row.id,
    childId: row.child_id,
    eventDate: row.event_date,
    targetTime: row.target_time,
    effectiveDeadline: row.effective_deadline,
    status: row.status,
    preNotifiedAt: row.pre_notified_at,
    targetNotifiedAt: row.target_notified_at,
    graceNotifiedAt: row.grace_notified_at,
    resolvedAt: row.resolved_at,
    childAckAt: row.child_ack_at,
    childAckReason: row.child_ack_reason,
    childAckNote: row.child_ack_note,
  };
}

homeByRouter.get('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await canViewChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }
    const result = await pool.query(
      `SELECT * FROM home_by_settings WHERE child_id = $1`,
      [childId],
    );
    if (!result.rows[0]) {
      res.json({
        settings: {
          childId,
          parentId,
          mode: 'off',
          customHour: null,
          customMinute: null,
          gracePeriodMinutes: 30,
          homeZoneId: null,
          weekendMode: 'off',
          weekendHour: null,
          weekendMinute: null,
          enabled: true,
        },
      });
      return;
    }
    res.json({ settings: mapSettings(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

homeByRouter.put('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await canManageChildFeatures(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }
    const body = putSchema.parse(req.body);

    if (body.homeZoneId) {
      const zone = await pool.query(
        `SELECT 1 FROM zones WHERE id = $1 AND child_id = $2 AND type = 'home'`,
        [body.homeZoneId, childId],
      );
      if (zone.rowCount === 0) {
        res.status(400).json({ error: 'invalid_home_zone' });
        return;
      }
    }

    const result = await pool.query(
      `INSERT INTO home_by_settings (
         child_id, parent_id, mode, custom_hour, custom_minute,
         grace_period_minutes, home_zone_id, weekend_mode,
         weekend_hour, weekend_minute, enabled, updated_at
       ) VALUES (
         $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now()
       )
       ON CONFLICT (child_id) DO UPDATE SET
         parent_id = EXCLUDED.parent_id,
         mode = EXCLUDED.mode,
         custom_hour = EXCLUDED.custom_hour,
         custom_minute = EXCLUDED.custom_minute,
         grace_period_minutes = EXCLUDED.grace_period_minutes,
         home_zone_id = EXCLUDED.home_zone_id,
         weekend_mode = EXCLUDED.weekend_mode,
         weekend_hour = EXCLUDED.weekend_hour,
         weekend_minute = EXCLUDED.weekend_minute,
         enabled = EXCLUDED.enabled,
         updated_at = now()
       RETURNING *`,
      [
        childId,
        parentId,
        body.mode,
        body.mode === 'custom' ? body.customHour ?? null : null,
        body.mode === 'custom' ? body.customMinute ?? null : null,
        body.gracePeriodMinutes ?? 30,
        body.homeZoneId ?? null,
        body.weekendMode ?? 'off',
        (body.weekendMode ?? 'off') === 'custom' ? body.weekendHour ?? null : null,
        (body.weekendMode ?? 'off') === 'custom' ? body.weekendMinute ?? null : null,
        body.enabled ?? true,
      ],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'home_by.settings_updated', $3::jsonb)`,
      [parentId, childId, JSON.stringify({ mode: body.mode })],
    );

    res.json({ settings: mapSettings(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

homeByRouter.get('/:childId/today', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const canView = await canViewChild(userId, childId);
    const isSelf = userId === childId && (await assertIsChild(userId));
    if (!canView && !isSelf) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const eventDate = jakartaDateString();
    const event = await pool.query(
      `SELECT * FROM home_by_events
       WHERE child_id = $1 AND event_date = $2::date`,
      [childId, eventDate],
    );
    const settings = await pool.query(
      `SELECT mode, custom_hour, custom_minute FROM home_by_settings WHERE child_id = $1`,
      [childId],
    );
    res.json({
      settings: settings.rows[0]
        ? {
            mode: settings.rows[0].mode,
            customHour: settings.rows[0].custom_hour,
            customMinute: settings.rows[0].custom_minute,
          }
        : { mode: 'off', customHour: null, customMinute: null },
      today: mapEvent(event.rows[0]),
    });
  } catch (error) {
    next(error);
  }
});

homeByRouter.get('/:childId/skip-dates', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await canViewChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }
    const result = await pool.query(
      `SELECT id, child_id, skip_date, note, created_by, created_at
       FROM home_by_skip_dates
       WHERE child_id = $1
       ORDER BY skip_date ASC`,
      [childId],
    );
    res.json({
      skipDates: result.rows.map((r) => ({
        id: r.id,
        childId: r.child_id,
        skipDate: r.skip_date,
        note: r.note,
        createdBy: r.created_by,
        createdAt: r.created_at,
      })),
    });
  } catch (error) {
    next(error);
  }
});

homeByRouter.post('/:childId/skip-dates', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await canManageChildFeatures(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }
    const body = z
      .object({
        skipDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
        note: z.string().max(120).optional(),
      })
      .parse(req.body);

    const result = await pool.query(
      `INSERT INTO home_by_skip_dates (child_id, skip_date, note, created_by)
       VALUES ($1, $2::date, $3, $4)
       ON CONFLICT (child_id, skip_date) DO UPDATE
         SET note = EXCLUDED.note
       RETURNING *`,
      [childId, body.skipDate, body.note ?? null, parentId],
    );
    res.status(201).json({
      skipDate: {
        id: result.rows[0].id,
        childId: result.rows[0].child_id,
        skipDate: result.rows[0].skip_date,
        note: result.rows[0].note,
        createdBy: result.rows[0].created_by,
        createdAt: result.rows[0].created_at,
      },
    });
  } catch (error) {
    next(error);
  }
});

homeByRouter.delete('/skip-dates/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const id = z.string().uuid().parse(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const existing = await pool.query(
      `SELECT s.id, s.child_id
       FROM home_by_skip_dates s
       JOIN parent_children pc ON pc.child_id = s.child_id
       WHERE s.id = $1 AND pc.parent_id = $2`,
      [id, parentId],
    );
    if (!existing.rows[0]) {
      res.status(404).json({ error: 'not_found' });
      return;
    }
    await pool.query(`DELETE FROM home_by_skip_dates WHERE id = $1`, [id]);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

homeByRouter.post('/:childId/ack', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (userId !== childId || !(await assertIsChild(userId))) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }
    const body = z
      .object({
        reason: z.enum(['in_transit', 'stopped_by', 'school_activity', 'other']),
        note: z.string().max(140).optional(),
      })
      .parse(req.body);

    const result = await applyAckForChild({
      childId,
      reason: body.reason,
      note: body.note,
    });
    if (!result.ok) {
      res.status(409).json({ error: result.error });
      return;
    }
    res.json({
      today: mapEvent(result.event as unknown as Record<string, unknown>),
      extendedTo: result.extendedTo,
    });
  } catch (error) {
    next(error);
  }
});
