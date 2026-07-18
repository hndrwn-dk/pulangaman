import { pool } from '../db/pool.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';
import { sendFcmToUser } from './fcm.js';
import { awardReward } from './rewards.js';

export async function recordSchoolAttendance(params: {
  childId: string;
  zoneId: string;
  event: 'enter' | 'exit';
  recordedAt?: Date;
}): Promise<void> {
  const school = await pool.query<{ school_id: string; parent_id: string }>(
    `SELECT cp.school_id, pc.parent_id
     FROM child_profiles cp
     JOIN parent_children pc ON pc.child_id = cp.user_id
     WHERE cp.user_id = $1 AND cp.school_id IS NOT NULL
     LIMIT 1`,
    [params.childId],
  );
  if (school.rowCount === 0) {
    return;
  }

  const { school_id: schoolId, parent_id: parentId } = school.rows[0];
  const eventType = params.event === 'enter' ? 'check_in' : 'check_out';
  const recordedAt = params.recordedAt ?? new Date();
  const localDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(recordedAt);
  const referenceKey = `attendance:${params.childId}:${schoolId}:${eventType}:${localDate}`;

  const result = await pool.query<{ id: string }>(
    `INSERT INTO attendance_events
       (child_id, school_id, zone_id, event_type, source, client_event_id, recorded_at)
     VALUES ($1, $2, $3, $4, 'geofence', $5, $6)
     ON CONFLICT (child_id, client_event_id) DO NOTHING
     RETURNING id`,
    [params.childId, schoolId, params.zoneId, eventType, referenceKey, recordedAt],
  );
  if (result.rowCount === 0) {
    return;
  }

  await pool.query(
    `UPDATE child_profiles
     SET commute_status = $2
     WHERE user_id = $1`,
    [params.childId, params.event === 'enter' ? 'school' : 'commuting'],
  );

  const payload = {
    attendanceId: result.rows[0].id,
    childId: params.childId,
    schoolId,
    event: eventType,
    recordedAt: recordedAt.toISOString(),
  };
  broadcastToRoom(childRoom(params.childId), 'parent:attendance', payload);
  await sendFcmToUser(
    parentId,
    {
      title: 'Kehadiran sekolah',
      body: params.event === 'enter' ? 'Anak sudah tiba di sekolah' : 'Anak meninggalkan sekolah',
    },
    {
      type: 'attendance_event',
      childId: params.childId,
      event: eventType,
    },
  );

  await pool.query(
    `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
     VALUES (NULL, $1, $2, $3::jsonb)`,
    [
      params.childId,
      `attendance.${eventType}`,
      JSON.stringify({ schoolId, attendanceId: result.rows[0].id }),
    ],
  );

  if (eventType === 'check_in') {
    await awardReward({
      childId: params.childId,
      delta: 10,
      reason: 'arrival_school',
      referenceKey: `reward:${referenceKey}`,
      metadata: { attendanceId: result.rows[0].id },
    });
  }
}
