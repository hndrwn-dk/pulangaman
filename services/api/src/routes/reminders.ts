import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { sendFcmToUser } from '../services/fcm.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';

export const remindersRouter = Router();
remindersRouter.use(requireAuth, rateLimit);

const daysSchema = z
  .array(z.number().int().min(1).max(7))
  .min(1)
  .max(7)
  .default([1, 2, 3, 4, 5, 6, 7]);

const upsertSchema = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(400),
  hour: z.number().int().min(0).max(23),
  minute: z.number().int().min(0).max(59),
  daysOfWeek: daysSchema,
  style: z.enum(['fullscreen', 'notification']).default('fullscreen'),
  enabled: z.boolean().default(true),
});

async function assertParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const link = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (link.rowCount ?? 0) > 0;
}

function mapReminder(row: {
  id: string;
  child_id: string;
  parent_id: string;
  title: string;
  body: string;
  hour: number;
  minute: number;
  days_of_week: number[];
  style: string;
  enabled: boolean;
  created_at: Date;
  updated_at: Date;
}) {
  return {
    id: row.id,
    childId: row.child_id,
    parentId: row.parent_id,
    title: row.title,
    body: row.body,
    hour: row.hour,
    minute: row.minute,
    daysOfWeek: row.days_of_week,
    style: row.style,
    enabled: row.enabled,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function notifyChildRemindersUpdated(childId: string) {
  broadcastToRoom(childRoom(childId), 'child:reminders_updated', {
    childId,
    at: new Date().toISOString(),
  });
  await sendFcmToUser(
    childId,
    {
      title: 'Pengingat diperbarui',
      body: 'Orang tua mengubah jadwal pengingat kamu.',
    },
    { type: 'reminders_sync', childId },
  ).catch(() => undefined);
}

/** Child pulls active reminders for local AlarmManager sync. */
remindersRouter.get('/me', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    if (!childId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const role = await pool.query(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
      [childId],
    );
    if (role.rowCount === 0) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }

    const result = await pool.query(
      `SELECT *
       FROM child_reminders
       WHERE child_id = $1 AND enabled = true
       ORDER BY hour ASC, minute ASC, title ASC`,
      [childId],
    );
    res.json({ reminders: result.rows.map(mapReminder) });
  } catch (error) {
    next(error);
  }
});

remindersRouter.get('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const result = await pool.query(
      `SELECT *
       FROM child_reminders
       WHERE child_id = $1 AND parent_id = $2
       ORDER BY hour ASC, minute ASC, title ASC`,
      [childId, parentId],
    );
    res.json({ reminders: result.rows.map(mapReminder) });
  } catch (error) {
    next(error);
  }
});

remindersRouter.post('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertParentOfChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const body = upsertSchema.parse(req.body);
    const uniqueDays = [...new Set(body.daysOfWeek)].sort((a, b) => a - b);

    const result = await pool.query(
      `INSERT INTO child_reminders
         (child_id, parent_id, title, body, hour, minute, days_of_week, style, enabled)
       VALUES ($1, $2, $3, $4, $5, $6, $7::integer[], $8, $9)
       RETURNING *`,
      [
        childId,
        parentId,
        body.title,
        body.body,
        body.hour,
        body.minute,
        uniqueDays,
        body.style,
        body.enabled,
      ],
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'reminder.created', $3::jsonb)`,
      [parentId, childId, JSON.stringify({ reminderId: result.rows[0].id })],
    );

    void notifyChildRemindersUpdated(childId);
    res.status(201).json({ reminder: mapReminder(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

remindersRouter.put('/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const reminderId = z.string().uuid().parse(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = upsertSchema.parse(req.body);
    const uniqueDays = [...new Set(body.daysOfWeek)].sort((a, b) => a - b);

    const result = await pool.query(
      `UPDATE child_reminders
       SET title = $3,
           body = $4,
           hour = $5,
           minute = $6,
           days_of_week = $7::integer[],
           style = $8,
           enabled = $9,
           updated_at = now()
       WHERE id = $1 AND parent_id = $2
       RETURNING *`,
      [
        reminderId,
        parentId,
        body.title,
        body.body,
        body.hour,
        body.minute,
        uniqueDays,
        body.style,
        body.enabled,
      ],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'reminder_not_found' });
      return;
    }

    void notifyChildRemindersUpdated(result.rows[0].child_id);
    res.json({ reminder: mapReminder(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

remindersRouter.delete('/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const reminderId = z.string().uuid().parse(req.params.id);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query<{ child_id: string }>(
      `DELETE FROM child_reminders
       WHERE id = $1 AND parent_id = $2
       RETURNING child_id`,
      [reminderId, parentId],
    );

    if (result.rowCount === 0) {
      res.status(404).json({ error: 'reminder_not_found' });
      return;
    }

    void notifyChildRemindersUpdated(result.rows[0].child_id);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});
