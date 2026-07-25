import { pool } from '../db/pool.js';
import { computeSafeRoute } from './safeRoute.js';
import {
  computeTripProgress,
  hasArrived,
  type LatLng,
} from './tripLogic.js';
import { broadcastToRoom, childRoom, parentRoom } from '../ws/server.js';

export type TripRow = {
  id: string;
  child_id: string;
  parent_id: string;
  from_zone_id: string;
  to_zone_id: string;
  status: 'planned' | 'active' | 'arrived' | 'cancelled';
  mode: string;
  distance_m: number | null;
  duration_sec: number | null;
  polyline: string | null;
  path: LatLng[] | null;
  progress: number;
  started_at: Date | null;
  arrived_at: Date | null;
  created_by: 'parent' | 'child';
  created_at: Date;
  updated_at: Date;
  from_name?: string | null;
  from_type?: string | null;
  to_name?: string | null;
  to_type?: string | null;
  from_lat?: number;
  from_lng?: number;
  to_lat?: number;
  to_lng?: number;
  to_radius_m?: number;
};

function zoneDisplayName(type: string | null | undefined, name: string | null | undefined): string {
  const trimmed = name?.trim();
  if (trimmed) return trimmed;
  if (type === 'home') return 'Rumah';
  if (type === 'school') return 'Sekolah';
  return 'Tempat';
}

export function mapTrip(row: TripRow) {
  return {
    id: row.id,
    childId: row.child_id,
    parentId: row.parent_id,
    fromZoneId: row.from_zone_id,
    toZoneId: row.to_zone_id,
    fromLabel: zoneDisplayName(row.from_type, row.from_name),
    toLabel: zoneDisplayName(row.to_type, row.to_name),
    fromType: row.from_type ?? null,
    toType: row.to_type ?? null,
    status: row.status,
    mode: row.mode,
    distanceM: row.distance_m,
    durationSec: row.duration_sec,
    polyline: row.polyline,
    path: row.path,
    progress: Number(row.progress) || 0,
    startedAt: row.started_at?.toISOString?.() ?? row.started_at,
    arrivedAt: row.arrived_at?.toISOString?.() ?? row.arrived_at,
    createdBy: row.created_by,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
  };
}

const tripSelect = `
  SELECT t.*,
         fz.name AS from_name, fz.type AS from_type,
         ST_Y(fz.center::geometry) AS from_lat,
         ST_X(fz.center::geometry) AS from_lng,
         tz.name AS to_name, tz.type AS to_type,
         ST_Y(tz.center::geometry) AS to_lat,
         ST_X(tz.center::geometry) AS to_lng,
         tz.radius_m AS to_radius_m
  FROM safe_trips t
  JOIN zones fz ON fz.id = t.from_zone_id
  JOIN zones tz ON tz.id = t.to_zone_id
`;

export async function getOpenTrip(childId: string): Promise<TripRow | null> {
  const result = await pool.query<TripRow>(
    `${tripSelect}
     WHERE t.child_id = $1 AND t.status IN ('planned', 'active')
     LIMIT 1`,
    [childId],
  );
  return result.rows[0] ?? null;
}

export async function getTripById(id: string): Promise<TripRow | null> {
  const result = await pool.query<TripRow>(
    `${tripSelect} WHERE t.id = $1`,
    [id],
  );
  return result.rows[0] ?? null;
}

function broadcastTrip(
  event: string,
  trip: TripRow,
  extra: Record<string, unknown> = {},
) {
  const payload = {
    ...mapTrip(trip),
    ...extra,
    at: new Date().toISOString(),
  };
  broadcastToRoom(childRoom(trip.child_id), event, payload);
  broadcastToRoom(parentRoom(trip.parent_id), event, payload);
}

async function loadZonePair(fromZoneId: string, toZoneId: string, childId: string) {
  const zones = await pool.query<{
    id: string;
    child_id: string;
    type: string;
    name: string | null;
    radius_m: number;
    lat: number;
    lng: number;
  }>(
    `SELECT id, child_id, type, name, radius_m,
            ST_Y(center::geometry) AS lat,
            ST_X(center::geometry) AS lng
     FROM zones
     WHERE id = ANY($1::uuid[])`,
    [[fromZoneId, toZoneId]],
  );
  const from = zones.rows.find((z) => z.id === fromZoneId);
  const to = zones.rows.find((z) => z.id === toZoneId);
  if (!from || !to) {
    return { error: 'zone_not_found' as const };
  }
  if (from.child_id !== childId || to.child_id !== childId) {
    return { error: 'zone_child_mismatch' as const };
  }
  return { from, to };
}

export async function createTrip(params: {
  childId: string;
  parentId: string;
  fromZoneId: string;
  toZoneId: string;
  createdBy: 'parent' | 'child';
  mode?: 'walking' | 'driving';
  startImmediately?: boolean;
}): Promise<{ ok: true; trip: TripRow } | { ok: false; error: string }> {
  if (params.fromZoneId === params.toZoneId) {
    return { ok: false, error: 'zones_must_differ' };
  }

  const existing = await getOpenTrip(params.childId);
  if (existing) {
    return { ok: false, error: 'trip_already_open' };
  }

  const pair = await loadZonePair(params.fromZoneId, params.toZoneId, params.childId);
  if ('error' in pair && pair.error) {
    return { ok: false, error: pair.error };
  }
  const { from, to } = pair as {
    from: { id: string; lat: number; lng: number };
    to: { id: string; lat: number; lng: number };
  };

  const mode = params.mode ?? 'walking';
  const route = await computeSafeRoute({
    originLat: Number(from.lat),
    originLng: Number(from.lng),
    destLat: Number(to.lat),
    destLng: Number(to.lng),
    mode,
  });

  const startNow = params.startImmediately === true || params.createdBy === 'child';
  const status = startNow ? 'active' : 'planned';

  const inserted = await pool.query<TripRow>(
    `INSERT INTO safe_trips (
       child_id, parent_id, from_zone_id, to_zone_id,
       status, mode, distance_m, duration_sec, polyline, path,
       progress, started_at, created_by
     ) VALUES (
       $1, $2, $3, $4,
       $5, $6, $7, $8, $9, $10::jsonb,
       0, $11, $12
     )
     RETURNING *`,
    [
      params.childId,
      params.parentId,
      params.fromZoneId,
      params.toZoneId,
      status,
      mode,
      route.distanceM,
      route.durationSec,
      route.polyline,
      JSON.stringify(route.path),
      startNow ? new Date() : null,
      params.createdBy,
    ],
  );

  const trip = await getTripById(inserted.rows[0].id);
  if (!trip) {
    return { ok: false, error: 'trip_create_failed' };
  }

  await pool.query(
    `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
     VALUES ($1, $2, $3, $4::jsonb)`,
    [
      params.createdBy === 'child' ? params.childId : params.parentId,
      params.childId,
      startNow ? 'trip.started' : 'trip.planned',
      JSON.stringify({
        tripId: trip.id,
        fromZoneId: trip.from_zone_id,
        toZoneId: trip.to_zone_id,
        fromLabel: zoneDisplayName(trip.from_type, trip.from_name),
        toLabel: zoneDisplayName(trip.to_type, trip.to_name),
      }),
    ],
  );

  broadcastTrip(startNow ? 'parent:trip_started' : 'parent:trip_planned', trip);
  return { ok: true, trip };
}

export async function startTrip(
  tripId: string,
): Promise<{ ok: true; trip: TripRow } | { ok: false; error: string }> {
  const current = await getTripById(tripId);
  if (!current) return { ok: false, error: 'not_found' };
  if (current.status === 'active') return { ok: true, trip: current };
  if (current.status !== 'planned') return { ok: false, error: 'not_startable' };

  await pool.query(
    `UPDATE safe_trips
     SET status = 'active', started_at = now(), updated_at = now()
     WHERE id = $1`,
    [tripId],
  );
  const trip = await getTripById(tripId);
  if (!trip) return { ok: false, error: 'not_found' };

  await pool.query(
    `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
     VALUES ($1, $2, 'trip.started', $3::jsonb)`,
    [
      trip.child_id,
      trip.child_id,
      JSON.stringify({
        tripId: trip.id,
        fromLabel: zoneDisplayName(trip.from_type, trip.from_name),
        toLabel: zoneDisplayName(trip.to_type, trip.to_name),
      }),
    ],
  );

  broadcastTrip('parent:trip_started', trip);
  return { ok: true, trip };
}

export async function cancelTrip(
  tripId: string,
  actorId: string,
): Promise<{ ok: true; trip: TripRow } | { ok: false; error: string }> {
  const current = await getTripById(tripId);
  if (!current) return { ok: false, error: 'not_found' };
  if (current.status !== 'planned' && current.status !== 'active') {
    return { ok: false, error: 'not_cancellable' };
  }

  await pool.query(
    `UPDATE safe_trips
     SET status = 'cancelled', updated_at = now()
     WHERE id = $1`,
    [tripId],
  );
  const trip = await getTripById(tripId);
  if (!trip) return { ok: false, error: 'not_found' };

  await pool.query(
    `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
     VALUES ($1, $2, 'trip.cancelled', $3::jsonb)`,
    [
      actorId,
      trip.child_id,
      JSON.stringify({
        tripId: trip.id,
        fromLabel: zoneDisplayName(trip.from_type, trip.from_name),
        toLabel: zoneDisplayName(trip.to_type, trip.to_name),
      }),
    ],
  );

  broadcastTrip('parent:trip_cancelled', trip);
  return { ok: true, trip };
}

export async function updateTripFromLocation(params: {
  childId: string;
  lat: number;
  lng: number;
}): Promise<void> {
  const trip = await getOpenTrip(params.childId);
  if (!trip || trip.status !== 'active') return;
  if (
    trip.from_lat == null ||
    trip.from_lng == null ||
    trip.to_lat == null ||
    trip.to_lng == null
  ) {
    return;
  }

  const origin: LatLng = { lat: Number(trip.from_lat), lng: Number(trip.from_lng) };
  const dest: LatLng = { lat: Number(trip.to_lat), lng: Number(trip.to_lng) };
  const current: LatLng = { lat: params.lat, lng: params.lng };
  const path = Array.isArray(trip.path) ? trip.path : null;

  const progress = computeTripProgress({ path, origin, dest, current });

  const zoneState = await pool.query<{ presence: string }>(
    `SELECT presence FROM zone_states
     WHERE child_id = $1 AND zone_id = $2`,
    [params.childId, trip.to_zone_id],
  );
  const insideDestZone = zoneState.rows[0]?.presence === 'inside';
  const arrived = hasArrived({
    current,
    dest,
    radiusM: Number(trip.to_radius_m ?? 100),
    insideDestZone,
  });

  if (arrived) {
    await pool.query(
      `UPDATE safe_trips
       SET status = 'arrived', progress = 1, arrived_at = now(), updated_at = now()
       WHERE id = $1 AND status = 'active'`,
      [trip.id],
    );
    const updated = await getTripById(trip.id);
    if (!updated) return;

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'trip.arrived', $3::jsonb)`,
      [
        params.childId,
        params.childId,
        JSON.stringify({
          tripId: updated.id,
          fromLabel: zoneDisplayName(updated.from_type, updated.from_name),
          toLabel: zoneDisplayName(updated.to_type, updated.to_name),
        }),
      ],
    );

    broadcastTrip('parent:trip_arrived', updated);
    return;
  }

  // Avoid noisy DB writes for tiny progress jitter.
  if (Math.abs(progress - Number(trip.progress)) < 0.01) {
    return;
  }

  await pool.query(
    `UPDATE safe_trips
     SET progress = $2, updated_at = now()
     WHERE id = $1 AND status = 'active'`,
    [trip.id, progress],
  );
  const updated = await getTripById(trip.id);
  if (!updated) return;
  broadcastTrip('parent:trip_progress', updated);
}
