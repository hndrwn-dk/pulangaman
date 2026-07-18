import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { isParentOfChild } from '../middleware/roles.js';

export const attendanceRouter = Router();
attendanceRouter.use(requireAuth, rateLimit);

attendanceRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.query.childId);
    const date = z.string().date().optional().parse(req.query.date);
    if (!userId || (userId !== childId && !(await isParentOfChild(userId, childId)))) {
      res.status(403).json({ error: 'child_access_required' });
      return;
    }

    const result = await pool.query(
      `SELECT ae.id, ae.school_id, s.name AS school_name, ae.event_type,
              ae.source, ae.recorded_at
       FROM attendance_events ae
       JOIN schools s ON s.id = ae.school_id
       WHERE ae.child_id = $1
         AND ($2::date IS NULL OR (ae.recorded_at AT TIME ZONE 'Asia/Jakarta')::date = $2::date)
       ORDER BY ae.recorded_at DESC
       LIMIT 100`,
      [childId, date ?? null],
    );
    res.json({ events: result.rows });
  } catch (error) {
    next(error);
  }
});

attendanceRouter.post('/manual', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const body = z
      .object({
        childId: z.string().uuid(),
        schoolId: z.string().uuid(),
        event: z.enum(['check_in', 'check_out']),
        recordedAt: z.string().datetime().optional(),
      })
      .parse(req.body);
    if (!parentId || !(await isParentOfChild(parentId, body.childId))) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }

    const result = await pool.query<{ id: string }>(
      `INSERT INTO attendance_events
         (child_id, school_id, event_type, source, recorded_at)
       VALUES ($1, $2, $3, 'manual', COALESCE($4::timestamptz, now()))
       RETURNING id`,
      [body.childId, body.schoolId, body.event, body.recordedAt ?? null],
    );
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'attendance.manual', $3::jsonb)`,
      [parentId, body.childId, JSON.stringify({ attendanceId: result.rows[0].id })],
    );
    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});
