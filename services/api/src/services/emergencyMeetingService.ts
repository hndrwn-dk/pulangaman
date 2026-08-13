import { pool } from '../db/pool.js';
import { childLocationKey, getRedis } from '../redis/client.js';
import { sendFcmToUser } from './fcm.js';
import { broadcastToRoom, childRoom, guardianAlertRoom, parentRoom } from '../ws/server.js';
import {
  ARRIVAL_RADIUS_METERS,
  buildActivationTargets,
  formatDistanceLabel,
  haversineMeters,
  isArrivedAt,
  type ActivateTargetResult,
} from './emergencyMeetingLogic.js';

export type MeetingPointRow = {
  id: string;
  child_id: string;
  parent_id: string;
  name: string;
  instructions: string | null;
  is_primary: boolean;
  lat: number;
  lng: number;
  created_at: Date;
  updated_at: Date;
};

export function mapPoint(row: MeetingPointRow) {
  return {
    id: row.id,
    childId: row.child_id,
    parentId: row.parent_id,
    name: row.name,
    instructions: row.instructions,
    isPrimary: row.is_primary,
    lat: Number(row.lat),
    lng: Number(row.lng),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

const pointSelect = `
  SELECT id, child_id, parent_id, name, instructions, is_primary,
         ST_Y(center::geometry) AS lat,
         ST_X(center::geometry) AS lng,
         created_at, updated_at
  FROM emergency_meeting_points
`;

export async function listPointsForChild(childId: string): Promise<MeetingPointRow[]> {
  const result = await pool.query<MeetingPointRow>(
    `${pointSelect}
     WHERE child_id = $1
     ORDER BY is_primary DESC, created_at ASC`,
    [childId],
  );
  return result.rows;
}

export async function getPrimaryPoint(childId: string): Promise<MeetingPointRow | null> {
  const result = await pool.query<MeetingPointRow>(
    `${pointSelect}
     WHERE child_id = $1 AND is_primary = true
     LIMIT 1`,
    [childId],
  );
  return result.rows[0] ?? null;
}

export async function getPointById(id: string): Promise<MeetingPointRow | null> {
  const result = await pool.query<MeetingPointRow>(
    `${pointSelect} WHERE id = $1`,
    [id],
  );
  return result.rows[0] ?? null;
}

async function clearPrimary(childId: string): Promise<void> {
  await pool.query(
    `UPDATE emergency_meeting_points
     SET is_primary = false, updated_at = now()
     WHERE child_id = $1 AND is_primary = true`,
    [childId],
  );
}

export async function createPoint(params: {
  childId: string;
  parentId: string;
  name: string;
  lat: number;
  lng: number;
  instructions?: string | null;
  isPrimary?: boolean;
}): Promise<MeetingPointRow> {
  const existing = await listPointsForChild(params.childId);
  const wantPrimary = params.isPrimary !== false || existing.length === 0;
  if (wantPrimary) {
    await clearPrimary(params.childId);
  }

  const inserted = await pool.query<{ id: string }>(
    `INSERT INTO emergency_meeting_points
       (child_id, parent_id, name, center, instructions, is_primary)
     VALUES (
       $1, $2, $3,
       ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
       $6, $7
     )
     RETURNING id`,
    [
      params.childId,
      params.parentId,
      params.name.trim(),
      params.lng,
      params.lat,
      params.instructions?.trim() || null,
      wantPrimary,
    ],
  );
  const row = await getPointById(inserted.rows[0].id);
  if (!row) throw new Error('point_create_failed');
  return row;
}

export async function updatePoint(params: {
  id: string;
  name?: string;
  lat?: number;
  lng?: number;
  instructions?: string | null;
  isPrimary?: boolean;
}): Promise<MeetingPointRow | null> {
  const current = await getPointById(params.id);
  if (!current) return null;

  if (params.isPrimary === true) {
    await clearPrimary(current.child_id);
  }

  const name = params.name?.trim() ?? current.name;
  const instructions =
    params.instructions !== undefined
      ? params.instructions?.trim() || null
      : current.instructions;
  const isPrimary =
    params.isPrimary !== undefined ? params.isPrimary : current.is_primary;
  const lat = params.lat ?? Number(current.lat);
  const lng = params.lng ?? Number(current.lng);

  await pool.query(
    `UPDATE emergency_meeting_points SET
       name = $2,
       instructions = $3,
       is_primary = $4,
       center = ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography,
       updated_at = now()
     WHERE id = $1`,
    [params.id, name, instructions, isPrimary, lng, lat],
  );
  return getPointById(params.id);
}

export async function deletePoint(id: string): Promise<boolean> {
  const result = await pool.query(`DELETE FROM emergency_meeting_points WHERE id = $1`, [
    id,
  ]);
  return (result.rowCount ?? 0) > 0;
}

/** Removes every meeting point owned by this parent (all children). */
export async function deleteAllPointsForParent(parentId: string): Promise<number> {
  const result = await pool.query(
    `DELETE FROM emergency_meeting_points WHERE parent_id = $1`,
    [parentId],
  );
  return result.rowCount ?? 0;
}

export async function applyPrimaryToChildren(params: {
  parentId: string;
  sourceChildId: string;
  targetChildIds: string[];
}): Promise<{ applied: string[] }> {
  const source = await getPrimaryPoint(params.sourceChildId);
  if (!source || source.parent_id !== params.parentId) {
    throw new Error('source_point_not_found');
  }

  const applied: string[] = [];
  for (const targetId of params.targetChildIds) {
    if (targetId === params.sourceChildId) continue;
    await clearPrimary(targetId);
    await pool.query(
      `INSERT INTO emergency_meeting_points
         (child_id, parent_id, name, center, instructions, is_primary)
       VALUES (
         $1, $2, $3,
         ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
         $6, true
       )`,
      [
        targetId,
        params.parentId,
        source.name,
        Number(source.lng),
        Number(source.lat),
        source.instructions,
      ],
    );
    applied.push(targetId);
  }
  return { applied };
}

async function latestChildLocation(
  childId: string,
): Promise<{ lat: number; lng: number; recordedAt: string | null } | null> {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }
    const cached = await redis.get(childLocationKey(childId));
    if (cached) {
      const parsed = JSON.parse(cached) as {
        lat?: number;
        lng?: number;
        recordedAt?: string;
      };
      if (typeof parsed.lat === 'number' && typeof parsed.lng === 'number') {
        return {
          lat: parsed.lat,
          lng: parsed.lng,
          recordedAt: parsed.recordedAt ?? null,
        };
      }
    }
  } catch {
    // Fall through to DB.
  }

  const last = await pool.query<{
    lat: number;
    lng: number;
    recorded_at: Date;
  }>(
    `SELECT ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng,
            recorded_at
     FROM location_history
     WHERE child_id = $1
     ORDER BY recorded_at DESC
     LIMIT 1`,
    [childId],
  );
  if (!last.rows[0]) return null;
  return {
    lat: Number(last.rows[0].lat),
    lng: Number(last.rows[0].lng),
    recordedAt: last.rows[0].recorded_at.toISOString(),
  };
}

export async function getChildPointStatus(childId: string) {
  const point = await getPrimaryPoint(childId);
  if (!point) {
    return {
      point: null,
      childDistanceMeters: null,
      childLastSeenAt: null,
      distanceLabel: '',
    };
  }
  const loc = await latestChildLocation(childId);
  const distance =
    loc == null
      ? null
      : haversineMeters(
          { lat: loc.lat, lng: loc.lng },
          { lat: Number(point.lat), lng: Number(point.lng) },
        );
  return {
    point: mapPoint(point),
    childDistanceMeters: distance,
    childLastSeenAt: loc?.recordedAt ?? null,
    distanceLabel: formatDistanceLabel(distance),
  };
}

async function approvedGuardianIds(childId: string): Promise<string[]> {
  const result = await pool.query<{ guardian_id: string }>(
    `SELECT guardian_id FROM child_approved_guardians
     WHERE child_id = $1 AND status = 'active'`,
    [childId],
  );
  return result.rows.map((r) => r.guardian_id);
}

export async function activateMeetingPoints(params: {
  parentId: string;
  note?: string | null;
}): Promise<{
  activationId: string;
  targets: ActivateTargetResult[];
  activatedAt: string;
}> {
  const recent = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM emergency_meeting_activations
     WHERE parent_id = $1 AND activated_at > now() - interval '1 hour'`,
    [params.parentId],
  );
  if (Number(recent.rows[0]?.count ?? 0) >= 3) {
    throw new Error('activation_rate_limited');
  }

  const children = await pool.query<{ id: string; name: string }>(
    `SELECT u.id, u.name FROM (
       SELECT child_id FROM parent_children WHERE parent_id = $1
       UNION
       SELECT child_id FROM child_approved_guardians
       WHERE guardian_id = $1
         AND status = 'active'
         AND access_level = 'co_parent'
     ) managed
     JOIN users u ON u.id = managed.child_id
     ORDER BY u.name`,
    [params.parentId],
  );

  const inputs = [];
  for (const child of children.rows) {
    const point = await getPrimaryPoint(child.id);
    const guardians = point ? await approvedGuardianIds(child.id) : [];
    inputs.push({
      childId: child.id,
      childName: child.name,
      meetingPointId: point?.id ?? null,
      meetingPointName: point?.name ?? null,
      guardianIds: guardians,
    });
  }

  const targets = buildActivationTargets(inputs);
  const note = params.note?.trim() || null;

  const inserted = await pool.query<{ id: string; activated_at: Date }>(
    `INSERT INTO emergency_meeting_activations (parent_id, note, targets)
     VALUES ($1, $2, $3::jsonb)
     RETURNING id, activated_at`,
    [params.parentId, note, JSON.stringify(targets)],
  );

  const activationId = inserted.rows[0].id;
  const activatedAt = inserted.rows[0].activated_at.toISOString();

  for (const t of targets) {
    if (!t.notified || !t.meetingPointId) continue;
    const point = await getPointById(t.meetingPointId);
    if (!point) continue;

    const title = 'Titik Kumpul Darurat';
    const body = note
      ? `${note} — menuju ${point.name}`
      : `Segera menuju titik kumpul: ${point.name}`;

    const data: Record<string, string> = {
      type: 'emergency_meeting_alert',
      activationId: String(activationId),
      childId: String(t.childId),
      meetingPointId: String(point.id),
      meetingPointName: String(point.name),
      lat: String(point.lat),
      lng: String(point.lng),
      instructions: point.instructions ?? '',
      note: note ?? '',
    };

    // FCM is best-effort — never fail the activation response if push/token errors.
    await sendFcmToUser(t.childId, { title, body }, data).catch((err) => {
      console.error('emp_activate_fcm_child_failed', { childId: t.childId, err });
    });
    broadcastToRoom(childRoom(t.childId), 'parent:emergency_meeting_alert', {
      activationId: String(activationId),
      childId: String(t.childId),
      meetingPointId: String(point.id),
      meetingPointName: String(point.name),
      lat: Number(point.lat),
      lng: Number(point.lng),
      instructions: point.instructions,
      note,
      at: activatedAt,
    });
  }

  const guardianPayloadById = new Map<
    string,
    { childNames: string[]; pointName: string; lat: string; lng: string }
  >();
  for (const t of targets) {
    if (!t.notified || !t.meetingPointId) continue;
    const point = await getPointById(t.meetingPointId);
    if (!point) continue;
    for (const gid of t.guardianIds) {
      const existing = guardianPayloadById.get(gid);
      if (existing) {
        existing.childNames.push(t.childName);
      } else {
        guardianPayloadById.set(gid, {
          childNames: [t.childName],
          pointName: point.name,
          lat: String(point.lat),
          lng: String(point.lng),
        });
      }
    }
  }

  for (const [guardianId, info] of guardianPayloadById) {
    const names = info.childNames.join(', ');
    await sendFcmToUser(
      guardianId,
      {
        title: 'Titik Kumpul Darurat',
        body: `${names} diminta menuju ${info.pointName}`,
      },
      {
        type: 'emergency_meeting_alert_guardian',
        activationId: String(activationId),
        meetingPointName: info.pointName,
        lat: info.lat,
        lng: info.lng,
        childNames: names,
        note: note ?? '',
      },
    ).catch((err) => {
      console.error('emp_activate_fcm_guardian_failed', { guardianId, err });
    });
    broadcastToRoom(guardianAlertRoom(guardianId), 'guardian:emergency_meeting_alert', {
      activationId,
      meetingPointName: info.pointName,
      lat: Number(info.lat),
      lng: Number(info.lng),
      childNames: info.childNames,
      note,
      at: activatedAt,
    });
  }

  const payload = {
    activationId,
    targets,
    activatedAt,
    note,
  };
  broadcastToRoom(parentRoom(params.parentId), 'parent:emergency_meeting_activated', payload);

  return { activationId, targets, activatedAt };
}

export { ARRIVAL_RADIUS_METERS };

export type ActivationChildStatus = {
  childId: string;
  childName: string;
  meetingPointId: string | null;
  meetingPointName: string | null;
  notified: boolean;
  lat: number | null;
  lng: number | null;
  childLat: number | null;
  childLng: number | null;
  distanceMeters: number | null;
  distanceLabel: string;
  arrived: boolean;
  lastSeenAt: string | null;
};

export type ActiveActivation = {
  activationId: string;
  activatedAt: string;
  note: string | null;
  children: ActivationChildStatus[];
};

/** Open activation for a parent, with each child's live distance to their point. */
export async function getActiveActivationForParent(
  parentId: string,
): Promise<ActiveActivation | null> {
  const result = await pool.query<{
    id: string;
    note: string | null;
    activated_at: Date;
    targets: ActivateTargetResult[];
  }>(
    `SELECT id, note, activated_at, targets
     FROM emergency_meeting_activations
     WHERE parent_id = $1
       AND resolved_at IS NULL
       AND activated_at > now() - interval '12 hours'
     ORDER BY activated_at DESC
     LIMIT 1`,
    [parentId],
  );

  const row = result.rows[0];
  if (!row) return null;

  const targets = Array.isArray(row.targets) ? row.targets : [];
  const children: ActivationChildStatus[] = [];
  for (const t of targets) {
    const point = t.meetingPointId ? await getPointById(t.meetingPointId) : null;
    const loc = point ? await latestChildLocation(t.childId) : null;
    const distance =
      point == null || loc == null
        ? null
        : haversineMeters(
            { lat: loc.lat, lng: loc.lng },
            { lat: Number(point.lat), lng: Number(point.lng) },
          );
    children.push({
      childId: t.childId,
      childName: t.childName,
      meetingPointId: point?.id ?? null,
      meetingPointName: point?.name ?? t.meetingPointName ?? null,
      notified: t.notified,
      lat: point ? Number(point.lat) : null,
      lng: point ? Number(point.lng) : null,
      childLat: loc?.lat ?? null,
      childLng: loc?.lng ?? null,
      distanceMeters: distance,
      distanceLabel: formatDistanceLabel(distance),
      arrived: isArrivedAt(distance),
      lastSeenAt: loc?.recordedAt ?? null,
    });
  }

  return {
    activationId: row.id,
    activatedAt: row.activated_at.toISOString(),
    note: row.note,
    children,
  };
}

/** Turn off every open activation for this parent; children/guardians get stand-down. */
export async function resolveActivations(params: {
  parentId: string;
}): Promise<{ resolved: number }> {
  const result = await pool.query<{
    id: string;
    targets: ActivateTargetResult[];
    resolved_at: Date;
  }>(
    `UPDATE emergency_meeting_activations
     SET resolved_at = now()
     WHERE parent_id = $1
       AND resolved_at IS NULL
     RETURNING id, targets, resolved_at`,
    [params.parentId],
  );

  for (const row of result.rows) {
    const resolvedAt = row.resolved_at.toISOString();
    const targets = Array.isArray(row.targets) ? row.targets : [];
    for (const t of targets) {
      if (!t.notified) continue;
      await sendFcmToUser(
        t.childId,
        {
          title: 'Titik Kumpul Dinonaktifkan',
          body: 'Kondisi darurat selesai. Ikuti arahan orang tua.',
        },
        {
          type: 'emergency_meeting_resolved',
          activationId: String(row.id),
          childId: String(t.childId),
        },
      ).catch((err) => {
        console.error('emp_resolve_fcm_child_failed', { childId: t.childId, err });
      });
      broadcastToRoom(childRoom(t.childId), 'parent:emergency_meeting_resolved', {
        activationId: String(row.id),
        childId: String(t.childId),
        at: resolvedAt,
      });
      for (const gid of t.guardianIds) {
        broadcastToRoom(guardianAlertRoom(gid), 'guardian:emergency_meeting_resolved', {
          activationId: String(row.id),
          at: resolvedAt,
        });
      }
    }
    broadcastToRoom(parentRoom(params.parentId), 'parent:emergency_meeting_resolved', {
      activationId: String(row.id),
      at: resolvedAt,
    });
  }

  return { resolved: result.rowCount ?? 0 };
}

/** Latest still-relevant activation for a child (last 6 hours, notified target). */
export async function getActiveAlertForChild(childId: string): Promise<{
  activationId: string;
  activatedAt: string;
  note: string | null;
  meetingPointName: string;
  lat: number;
  lng: number;
  instructions: string | null;
} | null> {
  const result = await pool.query<{
    id: string;
    note: string | null;
    activated_at: Date;
    targets: ActivateTargetResult[];
  }>(
    `SELECT a.id, a.note, a.activated_at, a.targets
     FROM emergency_meeting_activations a
     WHERE a.resolved_at IS NULL
       AND a.activated_at > now() - interval '6 hours'
       AND (
         EXISTS (
           SELECT 1 FROM parent_children pc
           WHERE pc.parent_id = a.parent_id AND pc.child_id = $1
         )
         OR EXISTS (
           SELECT 1 FROM child_approved_guardians cag
           WHERE cag.guardian_id = a.parent_id
             AND cag.child_id = $1
             AND cag.status = 'active'
             AND cag.access_level = 'co_parent'
         )
       )
     ORDER BY a.activated_at DESC
     LIMIT 8`,
    [childId],
  );

  for (const row of result.rows) {
    const targets = Array.isArray(row.targets) ? row.targets : [];
    const mine = targets.find((t) => t.childId === childId && t.notified);
    if (!mine?.meetingPointId) continue;
    const point = await getPointById(mine.meetingPointId);
    if (!point) continue;
    return {
      activationId: row.id,
      activatedAt: row.activated_at.toISOString(),
      note: row.note,
      meetingPointName: point.name,
      lat: Number(point.lat),
      lng: Number(point.lng),
      instructions: point.instructions,
    };
  }
  return null;
}
