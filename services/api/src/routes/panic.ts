import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const panicRouter = Router();

panicRouter.use(requireAuth);

const triggerSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

panicRouter.post('/trigger', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    if (!childId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = triggerSchema.parse(req.body);
    const parent = await pool.query<{ parent_id: string }>(
      `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
      [childId],
    );
    if (parent.rowCount === 0) {
      res.status(400).json({ error: 'parent_link_required' });
      return;
    }

    const parentId = parent.rows[0].parent_id;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const alert = await client.query<{ id: string }>(
        `INSERT INTO panic_alerts (child_id, parent_id, triggered_location)
         VALUES (
           $1,
           $2,
           ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography
         )
         RETURNING id`,
        [childId, parentId, body.lng, body.lat],
      );
      const alertId = alert.rows[0].id;

      // Immediate parent notify channel record (FCM delivery wired in Phase 1).
      await client.query(
        `INSERT INTO panic_alert_recipients (alert_id, user_id, channel)
         VALUES ($1, $2, 'fcm')`,
        [alertId, parentId],
      );

      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $1, 'panic.triggered', $2::jsonb)`,
        [childId, JSON.stringify({ alertId, parentId })],
      );

      await client.query('COMMIT');

      res.status(201).json({
        alertId,
        status: 'active',
        cascade: {
          parentFcmAt: 'immediate',
          parentSmsAtSeconds: 30,
          emergencyContactsAtSeconds: 60,
        },
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

panicRouter.post('/:id/ack', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const alertId = String(req.params.id);
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `UPDATE panic_alerts
       SET status = 'parent_responded'
       WHERE id = $1 AND parent_id = $2 AND status = 'active'
       RETURNING id`,
      [alertId, userId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    await pool.query(
      `UPDATE panic_alert_recipients
       SET ack_at = now()
       WHERE alert_id = $1 AND user_id = $2`,
      [alertId, userId],
    );

    res.json({ alertId, status: 'parent_responded' });
  } catch (error) {
    next(error);
  }
});

panicRouter.post('/:id/resolve', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const alertId = String(req.params.id);
    const notes = z
      .object({ notes: z.string().max(1000).optional() })
      .parse(req.body).notes;

    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `UPDATE panic_alerts
       SET status = 'resolved',
           resolved_at = now(),
           resolution_notes = $3
       WHERE id = $1
         AND (parent_id = $2 OR child_id = $2)
         AND status IN ('active', 'parent_responded', 'guardian_notified')
       RETURNING id`,
      [alertId, userId, notes ?? null],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'panic.resolved', $2::jsonb)`,
      [userId, JSON.stringify({ alertId })],
    );

    res.json({ alertId, status: 'resolved' });
  } catch (error) {
    next(error);
  }
});
