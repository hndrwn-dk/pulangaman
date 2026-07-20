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
  batteryLevel: z.number().min(0).max(100).optional(),
  batteryCharging: z.boolean().optional(),
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

    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }

    // Keep last known battery if this ping omitted it (common for some background paths).
    let batteryLevel =
      typeof body.batteryLevel === 'number' ? body.batteryLevel : null;
    let batteryCharging =
      typeof body.batteryCharging === 'boolean' ? body.batteryCharging : null;
    if (batteryLevel === null) {
      const prevRaw = await redis.get(childLocationKey(childId));
      if (prevRaw) {
        try {
          const prev = JSON.parse(prevRaw) as {
            batteryLevel?: number | null;
            batteryCharging?: boolean | null;
          };
          if (typeof prev.batteryLevel === 'number') {
            batteryLevel = prev.batteryLevel;
            batteryCharging = prev.batteryCharging === true;
          }
        } catch {
          // ignore corrupt cache
        }
      }
      if (batteryLevel === null) {
        const profile = await pool.query<{
          last_battery_level: number | null;
          last_battery_charging: boolean | null;
        }>(
          `SELECT last_battery_level, last_battery_charging
           FROM child_profiles WHERE user_id = $1`,
          [childId],
        );
        const row = profile.rows[0];
        if (row && typeof row.last_battery_level === 'number') {
          batteryLevel = row.last_battery_level;
          batteryCharging = row.last_battery_charging === true;
        }
      }
    }

    if (typeof body.batteryLevel === 'number') {
      await pool.query(
        `UPDATE child_profiles
         SET last_seen_at = $2,
             last_battery_level = $3,
             last_battery_charging = $4
         WHERE user_id = $1`,
        [
          childId,
          recordedAt,
          body.batteryLevel,
          body.batteryCharging === true,
        ],
      );
    } else {
      await pool.query(
        `UPDATE child_profiles
         SET last_seen_at = $2
         WHERE user_id = $1`,
        [childId, recordedAt],
      );
    }

    const payload = {
      childId,
      lat: body.lat,
      lng: body.lng,
      accuracyM: body.accuracyM ?? null,
      recordedAt,
      timestamp: recordedAt,
      accuracy: body.accuracyM ?? null,
      batteryLevel,
      batteryCharging,
    };

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
