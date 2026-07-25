import { pool } from '../db/pool.js';
import { config } from '../config.js';
import { sendFcmToUser } from './fcm.js';
import { getMaghribTime } from './prayerTimes.js';
import {
  applyChildAck,
  canAcceptChildAck,
  childPreNotifyCopy,
  daySkipReason,
  isResolvedHome,
  jakartaDateString,
  jakartaLocalDateTime,
  nextStatusAfterStage,
  parentGraceCopy,
  parentTargetCopy,
  resolveActiveClock,
  shouldEscalate,
  shouldNotifyTarget,
  shouldPreNotify,
  type ChildAckReason,
  type HomeByMode,
  type HomeByStatus,
  type WeekendMode,
} from './homeByLogic.js';
import { broadcastToRoom, childRoom, parentRoom } from '../ws/server.js';

type SettingsRow = {
  child_id: string;
  parent_id: string;
  mode: HomeByMode;
  custom_hour: number | null;
  custom_minute: number | null;
  grace_period_minutes: number;
  home_zone_id: string | null;
  weekend_mode: WeekendMode;
  weekend_hour: number | null;
  weekend_minute: number | null;
  enabled: boolean;
};

type EventRow = {
  id: string;
  child_id: string;
  event_date: string;
  target_time: Date;
  effective_deadline: Date;
  status: HomeByStatus;
  pre_notified_at: Date | null;
  target_notified_at: Date | null;
  grace_notified_at: Date | null;
  resolved_at: Date | null;
  child_ack_at: Date | null;
  child_ack_reason: ChildAckReason | null;
  child_ack_note: string | null;
};

function fmtClock(at: Date): string {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Jakarta',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(at);
}

async function loadHomeZone(childId: string, preferredZoneId: string | null) {
  if (preferredZoneId) {
    const preferred = await pool.query<{
      id: string;
      lat: number;
      lng: number;
    }>(
      `SELECT id, ST_Y(center::geometry) AS lat, ST_X(center::geometry) AS lng
       FROM zones WHERE id = $1 AND child_id = $2 AND type = 'home'`,
      [preferredZoneId, childId],
    );
    if (preferred.rows[0]) return preferred.rows[0];
  }
  const fallback = await pool.query<{
    id: string;
    lat: number;
    lng: number;
  }>(
    `SELECT id, ST_Y(center::geometry) AS lat, ST_X(center::geometry) AS lng
     FROM zones WHERE child_id = $1 AND type = 'home'
     ORDER BY created_at ASC LIMIT 1`,
    [childId],
  );
  return fallback.rows[0] ?? null;
}

async function isChildHome(childId: string, zoneId: string | null): Promise<boolean> {
  if (zoneId) {
    const state = await pool.query<{ presence: string }>(
      `SELECT presence FROM zone_states WHERE child_id = $1 AND zone_id = $2`,
      [childId, zoneId],
    );
    if (state.rows[0]?.presence === 'inside') return true;
  }
  const profile = await pool.query<{ commute_status: string | null }>(
    `SELECT commute_status FROM child_profiles WHERE user_id = $1`,
    [childId],
  );
  return profile.rows[0]?.commute_status === 'home';
}

async function childDisplayName(childId: string): Promise<string> {
  const row = await pool.query<{ name: string | null }>(
    `SELECT name FROM users WHERE id = $1`,
    [childId],
  );
  return row.rows[0]?.name?.trim() || 'Anak';
}

async function upsertEvent(params: {
  childId: string;
  eventDate: string;
  targetTime: Date;
  status?: HomeByStatus;
}): Promise<EventRow> {
  const status = params.status ?? 'pending';
  const result = await pool.query<EventRow>(
    `INSERT INTO home_by_events (
       child_id, event_date, target_time, effective_deadline, status
     ) VALUES ($1, $2::date, $3, $3, $4)
     ON CONFLICT (child_id, event_date) DO UPDATE
       SET target_time = CASE
             WHEN home_by_events.status IN ('pending') THEN EXCLUDED.target_time
             ELSE home_by_events.target_time
           END,
           effective_deadline = CASE
             WHEN home_by_events.status IN ('pending')
               AND home_by_events.child_ack_at IS NULL
             THEN EXCLUDED.target_time
             ELSE home_by_events.effective_deadline
           END,
           status = CASE
             WHEN home_by_events.status = 'pending' AND $4 = 'skipped'
             THEN 'skipped'
             ELSE home_by_events.status
           END
     RETURNING *`,
    [params.childId, params.eventDate, params.targetTime, status],
  );
  return result.rows[0];
}

async function updateEvent(
  id: string,
  patch: Partial<{
    status: HomeByStatus;
    pre_notified_at: Date;
    target_notified_at: Date;
    grace_notified_at: Date;
    resolved_at: Date;
    child_ack_at: Date;
    child_ack_reason: ChildAckReason;
    child_ack_note: string | null;
    effective_deadline: Date;
  }>,
): Promise<EventRow> {
  const result = await pool.query<EventRow>(
    `UPDATE home_by_events SET
       status = COALESCE($2, status),
       pre_notified_at = COALESCE($3, pre_notified_at),
       target_notified_at = COALESCE($4, target_notified_at),
       grace_notified_at = COALESCE($5, grace_notified_at),
       resolved_at = COALESCE($6, resolved_at),
       child_ack_at = COALESCE($7, child_ack_at),
       child_ack_reason = COALESCE($8, child_ack_reason),
       child_ack_note = COALESCE($9, child_ack_note),
       effective_deadline = COALESCE($10, effective_deadline)
     WHERE id = $1
     RETURNING *`,
    [
      id,
      patch.status ?? null,
      patch.pre_notified_at ?? null,
      patch.target_notified_at ?? null,
      patch.grace_notified_at ?? null,
      patch.resolved_at ?? null,
      patch.child_ack_at ?? null,
      patch.child_ack_reason ?? null,
      patch.child_ack_note ?? null,
      patch.effective_deadline ?? null,
    ],
  );
  return result.rows[0];
}

function broadcastStatus(parentId: string, childId: string, event: EventRow) {
  const payload = {
    childId,
    status: event.status,
    targetTime: event.target_time.toISOString(),
    effectiveDeadline: event.effective_deadline.toISOString(),
    childAckAt: event.child_ack_at?.toISOString() ?? null,
    childAckReason: event.child_ack_reason,
    at: new Date().toISOString(),
  };
  broadcastToRoom(childRoom(childId), 'parent:home_by_status', payload);
  broadcastToRoom(parentRoom(parentId), 'parent:home_by_status', payload);
}

async function processChild(settings: SettingsRow, now: Date): Promise<void> {
  const eventDate = jakartaDateString(now);

  const skipRows = await pool.query<{ skip_date: string }>(
    `SELECT skip_date::text AS skip_date
     FROM home_by_skip_dates
     WHERE child_id = $1 AND skip_date = $2::date`,
    [settings.child_id, eventDate],
  );
  const skipReason = daySkipReason({
    eventDate,
    skipDates: skipRows.rows.map((r) => r.skip_date.slice(0, 10)),
    weekendMode: settings.weekend_mode,
    at: now,
  });

  if (skipReason) {
    const dummyTarget = jakartaLocalDateTime(eventDate, { hour: 12, minute: 0 });
    const event = await upsertEvent({
      childId: settings.child_id,
      eventDate,
      targetTime: dummyTarget,
      status: 'skipped',
    });
    if (event.status === 'skipped') {
      broadcastStatus(settings.parent_id, settings.child_id, event);
    }
    return;
  }

  const homeZone = await loadHomeZone(settings.child_id, settings.home_zone_id);
  let maghrib = null as { hour: number; minute: number } | null;
  if (settings.mode === 'maghrib') {
    if (homeZone) {
      maghrib = await getMaghribTime(homeZone.lat, homeZone.lng, eventDate);
    } else {
      maghrib = {
        hour: config.MAGHRIB_FALLBACK_HOUR,
        minute: config.MAGHRIB_FALLBACK_MINUTE,
      };
    }
  }

  const active = resolveActiveClock({
    mode: settings.mode,
    customHour: settings.custom_hour,
    customMinute: settings.custom_minute,
    weekendMode: settings.weekend_mode,
    weekendHour: settings.weekend_hour,
    weekendMinute: settings.weekend_minute,
    maghrib,
    at: now,
  });

  if (active.kind === 'off' || !active.clock) {
    return;
  }

  const targetTime = jakartaLocalDateTime(eventDate, active.clock);
  let event = await upsertEvent({
    childId: settings.child_id,
    eventDate,
    targetTime,
  });

  if (event.status === 'resolved' || event.status === 'skipped') {
    return;
  }

  const home = await isChildHome(settings.child_id, homeZone?.id ?? null);
  if (isResolvedHome({ isHome: home, status: event.status })) {
    event = await updateEvent(event.id, {
      status: nextStatusAfterStage('resolved'),
      resolved_at: now,
    });
    broadcastStatus(settings.parent_id, settings.child_id, event);
    return;
  }

  const childName = await childDisplayName(settings.child_id);

  if (
    shouldPreNotify({
      now,
      targetTime: event.target_time,
      preNotifiedAt: event.pre_notified_at,
      status: event.status,
    })
  ) {
    const copy = childPreNotifyCopy({ childName });
    event = await updateEvent(event.id, {
      status: nextStatusAfterStage('pre'),
      pre_notified_at: now,
    });
    await sendFcmToUser(settings.child_id, copy, {
      type: 'home_by_reminder',
      childId: settings.child_id,
      title: copy.title,
      body: copy.body,
    }).catch(() => undefined);
    broadcastStatus(settings.parent_id, settings.child_id, event);
  }

  if (
    shouldNotifyTarget({
      now,
      effectiveDeadline: event.effective_deadline,
      targetNotifiedAt: event.target_notified_at,
      status: event.status,
    })
  ) {
    const copy = parentTargetCopy({
      childName,
      targetLabel: fmtClock(event.target_time),
      childAckReason: event.child_ack_reason,
    });
    event = await updateEvent(event.id, {
      status: nextStatusAfterStage('target'),
      target_notified_at: now,
    });
    await sendFcmToUser(settings.parent_id, copy, {
      type: 'home_by_alert',
      childId: settings.child_id,
      stage: 'target',
    }).catch(() => undefined);
    broadcastStatus(settings.parent_id, settings.child_id, event);
  }

  if (
    shouldEscalate({
      now,
      effectiveDeadline: event.effective_deadline,
      gracePeriodMinutes: settings.grace_period_minutes,
      graceNotifiedAt: event.grace_notified_at,
      status: event.status,
    })
  ) {
    const elapsedMin = Math.max(
      0,
      Math.round(
        (now.getTime() - event.effective_deadline.getTime()) / 60_000,
      ),
    );
    const copy = parentGraceCopy({
      childName,
      elapsedLabel: `${elapsedMin} menit`,
    });
    event = await updateEvent(event.id, {
      status: nextStatusAfterStage('grace'),
      grace_notified_at: now,
    });
    await sendFcmToUser(settings.parent_id, copy, {
      type: 'home_by_alert',
      childId: settings.child_id,
      stage: 'grace',
    }).catch(() => undefined);
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'home_by.escalated', $3::jsonb)`,
      [
        settings.parent_id,
        settings.child_id,
        JSON.stringify({
          eventId: event.id,
          elapsedMinutes: elapsedMin,
        }),
      ],
    );
    broadcastStatus(settings.parent_id, settings.child_id, event);
  }
}

export async function runHomeByCheck(now: Date = new Date()): Promise<number> {
  if (config.KILL_SWITCH_LOCATION_SHARE) {
    console.info('home_by_check_skipped_kill_switch');
    return 0;
  }

  const settings = await pool.query<SettingsRow>(
    `SELECT *
     FROM home_by_settings
     WHERE enabled = true AND mode <> 'off'`,
  );

  let processed = 0;
  for (const row of settings.rows) {
    try {
      await processChild(row, now);
      processed += 1;
    } catch (err) {
      console.error('home_by_child_failed', {
        childId: row.child_id,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }
  return processed;
}

export async function applyAckForChild(params: {
  childId: string;
  reason: ChildAckReason;
  note?: string | null;
}): Promise<
  | { ok: true; event: EventRow; extendedTo: string }
  | { ok: false; error: string }
> {
  const eventDate = jakartaDateString();
  const eventRes = await pool.query<EventRow>(
    `SELECT * FROM home_by_events
     WHERE child_id = $1 AND event_date = $2::date`,
    [params.childId, eventDate],
  );
  const event = eventRes.rows[0];
  if (!event) {
    return { ok: false, error: 'no_event_today' };
  }

  const gate = canAcceptChildAck({
    status: event.status,
    childAckAt: event.child_ack_at,
  });
  if (!gate.ok) return gate;

  const applied = applyChildAck({
    effectiveDeadline: event.effective_deadline,
    extensionMinutes: config.CHILD_ACK_EXTENSION_MINUTES,
    reason: params.reason,
    note: params.note,
  });

  const updated = await updateEvent(event.id, {
    child_ack_at: applied.childAckAt,
    child_ack_reason: applied.childAckReason,
    child_ack_note: applied.childAckNote,
    effective_deadline: applied.effectiveDeadline,
  });

  const parent = await pool.query<{ parent_id: string }>(
    `SELECT parent_id FROM home_by_settings WHERE child_id = $1`,
    [params.childId],
  );
  const parentId = parent.rows[0]?.parent_id;
  if (parentId) {
    const payload = {
      childId: params.childId,
      reason: applied.childAckReason,
      note: applied.childAckNote,
      extendedTo: applied.effectiveDeadline.toISOString(),
      at: applied.childAckAt.toISOString(),
    };
    broadcastToRoom(childRoom(params.childId), 'parent:home_by_ack', payload);
    broadcastToRoom(parentRoom(parentId), 'parent:home_by_ack', payload);
    broadcastStatus(parentId, params.childId, updated);
  }

  return {
    ok: true,
    event: updated,
    extendedTo: applied.effectiveDeadline.toISOString(),
  };
}
