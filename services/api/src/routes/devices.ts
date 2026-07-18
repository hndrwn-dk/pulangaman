import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const devicesRouter = Router();

devicesRouter.use(requireAuth);

const deviceSchema = z.object({
  fcmToken: z.string().min(1),
  platform: z.enum(['android', 'ios', 'web']),
});

devicesRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = deviceSchema.parse(req.body);
    const result = await pool.query<{ id: string }>(
      `INSERT INTO devices (user_id, fcm_token, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (fcm_token) DO UPDATE
         SET user_id = EXCLUDED.user_id,
             platform = EXCLUDED.platform,
             last_seen_at = now()
       RETURNING id`,
      [userId, body.fcmToken, body.platform],
    );

    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});
