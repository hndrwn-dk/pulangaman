import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { cancelPanicCascade, startPanicCascade } from '../services/panicCascade.js';

export const panicRouter = Router();

panicRouter.use(requireAuth, rateLimit);

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
    let alertId: string;
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
      alertId = alert.rows[0].id;

      await client.query(
        `INSERT INTO panic_alert_recipients (alert_id, user_id, channel)
         VALUES ($1, $2, 'fcm')
         ON CONFLICT DO NOTHING`,
        [alertId, parentId],
      );

      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $1, 'panic.triggered', $2::jsonb)`,
        [childId, JSON.stringify({ alertId, parentId })],
      );

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

    void startPanicCascade({
      alertId,
      childId,
      parentId,
      lat: body.lat,
      lng: body.lng,
    });

    res.status(201).json({
      alertId,
      status: 'active',
      cascade: {
        parentFcmAt: 'immediate',
        parentSmsAtSeconds: 30,
        emergencyContactsAtSeconds: 60,
        guardiansAtSeconds: 60,
      },
    });
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
       WHERE id = $1 AND parent_id = $2 AND status IN ('active', 'guardian_notified')
       RETURNING id`,
      [alertId, userId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    cancelPanicCascade(alertId);

    await pool.query(
      `UPDATE panic_alert_recipients
       SET ack_at = now()
       WHERE alert_id = $1 AND user_id = $2`,
      [alertId, userId],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'panic.parent_ack', $2::jsonb)`,
      [userId, JSON.stringify({ alertId })],
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

    cancelPanicCascade(alertId);

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

/** Guardian ack for an alert they were notified about. */
panicRouter.post('/:id/guardian-ack', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    const alertId = String(req.params.id);
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const recipient = await pool.query(
      `SELECT 1 FROM panic_alert_recipients
       WHERE alert_id = $1 AND user_id = $2`,
      [alertId, guardianId],
    );
    if (recipient.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    await pool.query(
      `UPDATE panic_alert_recipients
       SET ack_at = now()
       WHERE alert_id = $1 AND user_id = $2`,
      [alertId, guardianId],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, action, payload)
       VALUES ($1, 'panic.guardian_ack', $2::jsonb)`,
      [guardianId, JSON.stringify({ alertId })],
    );

    res.json({ alertId, acknowledged: true });
  } catch (error) {
    next(error);
  }
});

panicRouter.post('/:id/need-backup', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    const alertId = String(req.params.id);
    const notes = z
      .object({ notes: z.string().max(500).optional() })
      .parse(req.body).notes;

    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const recipient = await pool.query(
      `SELECT pa.child_id, pa.parent_id
       FROM panic_alert_recipients par
       JOIN panic_alerts pa ON pa.id = par.alert_id
       WHERE par.alert_id = $1 AND par.user_id = $2
         AND pa.status IN ('active', 'parent_responded', 'guardian_notified')`,
      [alertId, guardianId],
    );
    if (recipient.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    const { child_id: childId, parent_id: parentId } = recipient.rows[0] as {
      child_id: string;
      parent_id: string;
    };

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'panic.need_backup', $3::jsonb)`,
      [guardianId, childId, JSON.stringify({ alertId, notes: notes ?? null })],
    );

    const { sendFcmToUser } = await import('../services/fcm.js');
    await sendFcmToUser(
      parentId,
      {
        title: 'PulangAman — Butuh bantuan',
        body: 'Wali terpercaya meminta cadangan. Hubungi layanan darurat bila perlu.',
      },
      { type: 'need_backup', alertId, childId },
    );

    res.json({ alertId, needBackup: true });
  } catch (error) {
    next(error);
  }
});
