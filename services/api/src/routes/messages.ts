import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
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
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const role = await pool.query(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'parent'`,
      [parentId],
    );
    if (role.rowCount === 0) {
      res.status(403).json({ error: 'parent_role_required' });
      return;
    }

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
         ae.payload->>'text' AS text,
         ae.payload->>'preset' AS preset,
         ae.created_at AS sent_at
       FROM audit_events ae
       JOIN parent_children pc ON pc.child_id = ae.subject_child_id
       JOIN users u ON u.id = ae.subject_child_id
       WHERE pc.parent_id = $1
         AND ae.action = 'child.message'
         AND ae.created_at > now() - interval '24 hours'
       ORDER BY ae.created_at DESC
       LIMIT 50`,
      [parentId],
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
