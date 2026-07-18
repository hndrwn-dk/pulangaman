import { pool } from '../db/pool.js';
import { config } from '../config.js';
import { sendFcmToUser } from './fcm.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';
import { nextPresence, shouldEmitZoneEvent, type Presence } from './geofenceLogic.js';

type ZoneRow = {
  id: string;
  type: string;
  radius_m: number;
  distance_m: number;
};

/**
 * Evaluate circular zones for a child location with hysteresis + debounce.
 * Enter when distance <= radius; exit when distance > radius + hysteresis.
 * Debounce prevents FCM spam on boundary jitter.
 */
export async function evaluateGeofences(params: {
  childId: string;
  lat: number;
  lng: number;
}): Promise<void> {
  const zones = await pool.query<ZoneRow>(
    `SELECT id, type, radius_m,
            ST_Distance(
              center,
              ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
            ) AS distance_m
     FROM zones
     WHERE child_id = $1`,
    [params.childId, params.lng, params.lat],
  );

  if (zones.rowCount === 0) {
    return;
  }

  const parent = await pool.query<{ parent_id: string }>(
    `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
    [params.childId],
  );
  const parentId = parent.rows[0]?.parent_id;

  for (const zone of zones.rows) {
    const state = await pool.query<{ presence: Presence; last_event_at: Date | null }>(
      `SELECT presence, last_event_at FROM zone_states
       WHERE child_id = $1 AND zone_id = $2`,
      [params.childId, zone.id],
    );

    const previous: Presence = state.rows[0]?.presence ?? 'unknown';
    const next = nextPresence({
      previous,
      distanceM: Number(zone.distance_m),
      radiusM: zone.radius_m,
      hysteresisM: config.ZONE_HYSTERESIS_M,
    });

    if (next === previous && state.rowCount) {
      continue;
    }

    const lastEventAt = state.rows[0]?.last_event_at
      ? new Date(state.rows[0].last_event_at).getTime()
      : 0;
    const sinceLast = Date.now() - lastEventAt;
    const isTransition = previous !== 'unknown' && next !== previous;
    const emit = shouldEmitZoneEvent({
      previous,
      next,
      sinceLastEventMs: sinceLast,
      debounceMs: config.ZONE_DEBOUNCE_SECONDS * 1000,
    });

    if (isTransition && !emit) {
      continue;
    }

    await pool.query(
      `INSERT INTO zone_states (child_id, zone_id, presence, last_event_at, updated_at)
       VALUES ($1, $2, $3, now(), now())
       ON CONFLICT (child_id, zone_id) DO UPDATE
         SET presence = EXCLUDED.presence,
             last_event_at = CASE
               WHEN $4 THEN now()
               ELSE zone_states.last_event_at
             END,
             updated_at = now()`,
      [params.childId, zone.id, next, isTransition && emit],
    );

    if (!emit || !parentId) {
      continue;
    }

    const event = next === 'inside' ? 'enter' : 'exit';
    const payload = {
      childId: params.childId,
      zoneId: zone.id,
      zoneType: zone.type,
      event,
    };

    broadcastToRoom(childRoom(params.childId), 'parent:zone_event', payload);

    await sendFcmToUser(
      parentId,
      {
        title: 'PulangAman',
        body:
          event === 'enter'
            ? `Anak memasuki zona ${zone.type}`
            : `Anak meninggalkan zona ${zone.type}`,
      },
      {
        type: 'zone_event',
        childId: params.childId,
        zoneType: zone.type,
        event,
      },
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES (NULL, $1, 'zone.event', $2::jsonb)`,
      [params.childId, JSON.stringify(payload)],
    );
  }
}
