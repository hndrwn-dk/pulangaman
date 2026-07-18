import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { childLocationKey, getRedis } from '../redis/client.js';
import { config } from '../config.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { evaluateGeofences } from '../services/geofence.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';

export const locationRouter = Router();

locationRouter.use(requireAuth, rateLimit);

const locationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracyM: z.number().positive().optional(),
  recordedAt: z.string().datetime().optional(),
  source: z.string().max(40).default('device'),
});

locationRouter.post('/', async (req: AuthedRequest, res, next) => {
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

    const body = locationSchema.parse(req.body);
    const recordedAt = body.recordedAt ?? new Date().toISOString();

    await pool.query(
      `INSERT INTO location_history (child_id, recorded_at, location, accuracy_m, source)
       VALUES (
         $1,
         $2,
         ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
         $5,
         $6
       )`,
      [childId, recordedAt, body.lng, body.lat, body.accuracyM ?? null, body.source],
    );

    await pool.query(
      `UPDATE child_profiles
       SET last_seen_at = $2, commute_status = 'commuting'
       WHERE user_id = $1`,
      [childId, recordedAt],
    );

    const payload = {
      childId,
      lat: body.lat,
      lng: body.lng,
      accuracyM: body.accuracyM ?? null,
      recordedAt,
      timestamp: recordedAt,
      accuracy: body.accuracyM ?? null,
    };

    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }
    await redis.set(
      childLocationKey(childId),
      JSON.stringify(payload),
      'EX',
      config.LOCATION_TTL_SECONDS,
    );

    broadcastToRoom(childRoom(childId), 'child:location_update', payload);

    void evaluateGeofences({
      childId,
      lat: body.lat,
      lng: body.lng,
    }).catch((error) => {
      console.error('geofence_eval_failed', error);
    });

    res.status(202).json({ accepted: true });
  } catch (error) {
    next(error);
  }
});
