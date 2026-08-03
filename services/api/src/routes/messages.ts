import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { hasRole, listViewableChildren } from '../middleware/roles.js';
import { sendFcmToUser } from '../services/fcm.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';

export const messagesRouter = Router();

messagesRouter.use(requireAuth, rateLimit);

const sendSchema = z.object({
  text: z.string().min(1).max(280),
  preset: z.string().max(60).optional(),
});

messagesRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // Primary parents and active guardians (view / co_parent) may read kabar.
    const allowed = await hasRole(userId, ['parent', 'guardian']);
    if (!allowed) {
      res.status(403).json({ error: 'parent_or_guardian_role_required' });
      return;
    }

    const children = await listViewableChildren(userId);
    if (children.length === 0) {
      res.json({ messages: [] });
      return;
    }
    const childIds = children.map((c) => c.id);

    const result = await pool.query<{
      id: string;
      child_id: string;
      child_name: string;
      text: string | null;
      preset: string | null;
      sent_at: Date;
    }>(
      `SELECT
         ae.id,
         ae.subject_child_id AS child_id,
         u.name AS child_name,
         CASE
           WHEN ae.action = 'child.message' THEN ae.payload->>'text'
           WHEN ae.action = 'panic.triggered' THEN 'TOMBOL PANIK ditekan'
           WHEN ae.action = 'panic.parent_ack' THEN 'Orang tua sudah merespons panik'
           WHEN ae.action = 'panic.resolved' THEN 'Panik selesai / aman'
           WHEN ae.action = 'trip.arrived' THEN
             'Sudah sampai di ' || COALESCE(ae.payload->>'toLabel', 'tujuan')
           WHEN ae.action = 'trip.started' THEN
             'Mulai perjalanan ke ' || COALESCE(ae.payload->>'toLabel', 'tujuan')
           ELSE ae.payload->>'text'
         END AS text,
         CASE
           WHEN ae.action = 'child.message' THEN ae.payload->>'preset'
           WHEN ae.action = 'panic.triggered' THEN 'panic'
           WHEN ae.action = 'panic.parent_ack' THEN 'panic_acked'
           WHEN ae.action = 'panic.resolved' THEN 'panic_resolved'
           WHEN ae.action = 'trip.arrived' THEN 'trip_arrived'
           WHEN ae.action = 'trip.started' THEN 'trip_started'
           ELSE ae.payload->>'preset'
         END AS preset,
         ae.created_at AS sent_at
       FROM audit_events ae
       JOIN users u ON u.id = ae.subject_child_id
       WHERE ae.subject_child_id = ANY($1::uuid[])
         AND ae.action IN (
           'child.message',
           'panic.triggered',
           'panic.parent_ack',
           'panic.resolved',
           'trip.started',
           'trip.arrived'
         )
         AND ae.created_at > now() - interval '7 days'
       ORDER BY ae.created_at DESC
       LIMIT 50`,
      [childIds],
    );

    res.json({
      messages: result.rows.map((row) => ({
        id: row.id,
        childId: row.child_id,
        childName: row.child_name,
        text: row.text ?? '',
        preset: row.preset,
        sentAt: row.sent_at,
      })),
    });
  } catch (error) {
    next(error);
  }
});

messagesRouter.post('/', async (req: AuthedRequest, res, next) => {
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

    const body = sendSchema.parse(req.body);
    const parent = await pool.query<{ parent_id: string }>(
      `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
      [childId],
    );
    if (parent.rowCount === 0) {
      res.status(400).json({ error: 'parent_link_required' });
      return;
    }

    const parentId = parent.rows[0].parent_id;
    const childName = await pool.query<{ name: string }>(
      `SELECT name FROM users WHERE id = $1`,
      [childId],
    );
    const name = childName.rows[0]?.name ?? 'Anak';

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $1, 'child.message', $2::jsonb)`,
      [
        childId,
        JSON.stringify({
          parentId,
          text: body.text,
          preset: body.preset ?? null,
        }),
      ],
    );

    const payload = {
      childId,
      childName: name,
      text: body.text,
      preset: body.preset ?? null,
      sentAt: new Date().toISOString(),
    };
    broadcastToRoom(childRoom(childId), 'child:message', payload);

    await sendFcmToUser(
      parentId,
      {
        title: `Kabar dari ${name}`,
        body: body.text,
      },
      { type: 'child_message', childId, text: body.text },
    );

    res.status(201).json({ ok: true, parentId });
  } catch (error) {
    next(error);
  }
});
