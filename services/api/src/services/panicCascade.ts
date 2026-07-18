import { pool } from '../db/pool.js';
import { config } from '../config.js';
import { sendFcmToUser } from './fcm.js';
import { sendSms } from './sms.js';
import { broadcastToRoom, childRoom, guardianAlertRoom } from '../ws/server.js';
import { childLocationKey, getRedis } from '../redis/client.js';

type CascadeTimers = {
  sms?: NodeJS.Timeout;
  escalate?: NodeJS.Timeout;
};

const timers = new Map<string, CascadeTimers>();

export function cancelPanicCascade(alertId: string): void {
  const existing = timers.get(alertId);
  if (!existing) {
    return;
  }
  if (existing.sms) clearTimeout(existing.sms);
  if (existing.escalate) clearTimeout(existing.escalate);
  timers.delete(alertId);
}

async function alertStillActive(alertId: string): Promise<boolean> {
  const result = await pool.query<{ status: string }>(
    `SELECT status FROM panic_alerts WHERE id = $1`,
    [alertId],
  );
  const status = result.rows[0]?.status;
  return status === 'active';
}

async function notifyParentSms(alertId: string, parentId: string, childId: string): Promise<void> {
  if (!(await alertStillActive(alertId))) {
    return;
  }

  const parent = await pool.query<{ phone: string; name: string }>(
    `SELECT phone, name FROM users WHERE id = $1`,
    [parentId],
  );
  const phone = parent.rows[0]?.phone;
  if (!phone) {
    return;
  }

  await sendSms(
    phone,
    `PulangAman PANIK: anak membutuhkan bantuan segera. Buka aplikasi untuk lokasi.`,
  );

  await pool.query(
    `INSERT INTO panic_alert_recipients (alert_id, user_id, channel)
     VALUES ($1, $2, 'sms')
     ON CONFLICT DO NOTHING`,
    [alertId, parentId],
  );

  await pool.query(
    `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
     VALUES ($1, $2, 'panic.parent_sms', $3::jsonb)`,
    [parentId, childId, JSON.stringify({ alertId })],
  );
}

async function notifyEmergencyContacts(alertId: string, childId: string): Promise<void> {
  const contacts = await pool.query<{ name: string; phone: string }>(
    `SELECT name, phone FROM emergency_contacts
     WHERE child_id = $1
     ORDER BY priority ASC
     LIMIT 5`,
    [childId],
  );

  for (const contact of contacts.rows) {
    await sendSms(
      contact.phone,
      `PulangAman: kontak darurat — anak terkait ${contact.name} memicu panik. Hubungi orang tua segera.`,
    );
  }

  if ((contacts.rowCount ?? 0) > 0) {
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES (NULL, $1, 'panic.emergency_contacts', $2::jsonb)`,
      [childId, JSON.stringify({ alertId, count: contacts.rowCount })],
    );
  }
}

async function notifyGuardians(params: {
  alertId: string;
  childId: string;
  lat: number;
  lng: number;
}): Promise<void> {
  if (config.KILL_SWITCH_GUARDIAN_NOTIFY) {
    console.warn('kill_switch_guardian_notify_active', { alertId: params.alertId });
    return;
  }

  const guardians = await pool.query<{
    guardian_id: string;
    distance_m: number | null;
  }>(
    `SELECT cag.guardian_id,
            CASE
              WHEN gp.home_location IS NULL THEN NULL
              ELSE ST_Distance(
                gp.home_location,
                ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
              )
            END AS distance_m
     FROM child_approved_guardians cag
     JOIN guardian_profiles gp ON gp.user_id = cag.guardian_id
     WHERE cag.child_id = $1
       AND cag.status = 'active'
       AND gp.status = 'active'
     ORDER BY distance_m ASC NULLS LAST
     LIMIT 3`,
    [params.childId, params.lng, params.lat],
  );

  for (const guardian of guardians.rows) {
    await pool.query(
      `INSERT INTO panic_alert_recipients (alert_id, user_id, channel)
       VALUES ($1, $2, 'fcm')
       ON CONFLICT DO NOTHING`,
      [params.alertId, guardian.guardian_id],
    );

    const payload = {
      alertId: params.alertId,
      childId: params.childId,
      childLocation: { lat: params.lat, lng: params.lng },
    };

    broadcastToRoom(guardianAlertRoom(guardian.guardian_id), 'guardian:alert_notify', payload);

    await sendFcmToUser(
      guardian.guardian_id,
      {
        title: 'PulangAman — Peringatan anak',
        body: 'Anak terpercaya memicu panik. Hubungi orang tua / layanan darurat. Jangan kejar orang asing.',
      },
      {
        type: 'guardian_alert',
        alertId: params.alertId,
        childId: params.childId,
      },
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'panic.guardian_notified', $3::jsonb)`,
      [
        guardian.guardian_id,
        params.childId,
        JSON.stringify({ alertId: params.alertId, distanceM: guardian.distance_m }),
      ],
    );
  }

  if ((guardians.rowCount ?? 0) > 0) {
    await pool.query(
      `UPDATE panic_alerts
       SET status = 'guardian_notified'
       WHERE id = $1 AND status = 'active'`,
      [params.alertId],
    );
  }
}

async function escalate(alertId: string, childId: string, lat: number, lng: number): Promise<void> {
  if (!(await alertStillActive(alertId))) {
    return;
  }

  await notifyEmergencyContacts(alertId, childId);
  await notifyGuardians({ alertId, childId, lat, lng });
}

export async function startPanicCascade(params: {
  alertId: string;
  childId: string;
  parentId: string;
  lat: number;
  lng: number;
}): Promise<void> {
  cancelPanicCascade(params.alertId);

  await sendFcmToUser(
    params.parentId,
    {
      title: 'PulangAman PANIK',
      body: 'Anak memicu tombol panik. Buka aplikasi sekarang.',
    },
    {
      type: 'panic',
      alertId: params.alertId,
      childId: params.childId,
    },
  );

  broadcastToRoom(childRoom(params.childId), 'child:panic_triggered', {
    alertId: params.alertId,
    childId: params.childId,
    location: { lat: params.lat, lng: params.lng },
    type: 'normal',
  });

  const entry: CascadeTimers = {};
  entry.sms = setTimeout(() => {
    void notifyParentSms(params.alertId, params.parentId, params.childId);
  }, config.PANIC_SMS_DELAY_MS);

  entry.escalate = setTimeout(() => {
    void escalate(params.alertId, params.childId, params.lat, params.lng);
  }, config.PANIC_ESCALATE_DELAY_MS);

  timers.set(params.alertId, entry);
}

export async function resolveChildLocationHint(
  childId: string,
  fallback: { lat: number; lng: number },
): Promise<{ lat: number; lng: number }> {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }
    const cached = await redis.get(childLocationKey(childId));
    if (!cached) {
      return fallback;
    }
    const parsed = JSON.parse(cached) as { lat?: number; lng?: number };
    if (typeof parsed.lat === 'number' && typeof parsed.lng === 'number') {
      return { lat: parsed.lat, lng: parsed.lng };
    }
  } catch {
    // fall through
  }
  return fallback;
}
