import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const authRouter = Router();

const sessionBodySchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20).optional(),
  email: z.string().email().optional(),
  role: z.enum(['parent', 'child', 'guardian']).default('parent'),
});

authRouter.post('/session', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const body = sessionBodySchema.parse(req.body);
    const firebaseUid = req.auth!.firebaseUid;
    const phone = body.phone ?? req.auth?.phone;
    if (!phone) {
      res.status(400).json({ error: 'phone_required' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Claim pending invite placeholder (pending:{phone}) onto this Firebase identity.
      const pending = await client.query<{ id: string }>(
        `SELECT id FROM users
         WHERE phone = $1 AND firebase_uid = $2
         LIMIT 1`,
        [phone, `pending:${phone}`],
      );

      let userId: string;

      if (pending.rowCount && pending.rows[0]) {
        userId = pending.rows[0].id;
        await client.query(
          `UPDATE users
           SET firebase_uid = $2,
               email = COALESCE($3, email),
               name = $4,
               updated_at = now()
           WHERE id = $1`,
          [userId, firebaseUid, body.email ?? null, body.name],
        );
      } else {
        const upsert = await client.query<{ id: string }>(
          `INSERT INTO users (firebase_uid, phone, email, name)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (firebase_uid) DO UPDATE
             SET phone = EXCLUDED.phone,
                 email = COALESCE(EXCLUDED.email, users.email),
                 name = EXCLUDED.name,
                 updated_at = now()
           RETURNING id`,
          [firebaseUid, phone, body.email ?? null, body.name],
        );
        userId = upsert.rows[0].id;
      }

      await client.query(
        `INSERT INTO user_roles (user_id, role)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [userId, body.role],
      );

      if (body.role === 'child') {
        await client.query(
          `INSERT INTO child_profiles (user_id)
           VALUES ($1)
           ON CONFLICT DO NOTHING`,
          [userId],
        );
      }

      if (body.role === 'guardian') {
        await client.query(
          `INSERT INTO guardian_profiles (user_id)
           VALUES ($1)
           ON CONFLICT DO NOTHING`,
          [userId],
        );
      }

      await client.query(
        `INSERT INTO audit_events (actor_id, action, payload)
         VALUES ($1, 'auth.session', $2::jsonb)`,
        [userId, JSON.stringify({ role: body.role })],
      );

      await client.query('COMMIT');

      res.status(201).json({
        userId,
        firebaseUid,
        role: body.role,
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
