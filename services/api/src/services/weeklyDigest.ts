import { jakartaDateString, jakartaWeekday } from './homeByLogic.js';
import { pool } from '../db/pool.js';
import { broadcastToRoom, parentRoom } from '../ws/server.js';
import { sendFcmToUser } from './fcm.js';
import { getOrCreateScreenTimeInsight } from './screentimeInsights.js';
import { config } from '../config.js';

export type DigestChildSummary = {
  childId: string;
  childName: string;
  streakText: string;
  kabarCount: number;
  hasUsageData: boolean;
};

type ParentChildRow = {
  parent_id: string;
  child_id: string;
  child_name: string | null;
};

/** Jakarta wall-clock hour (0–23). */
export function jakartaHour(at: Date = new Date()): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Jakarta',
    hour: 'numeric',
    hour12: false,
  }).formatToParts(at);
  const hour = parts.find((p) => p.type === 'hour')?.value ?? '0';
  // Intl may return "24" for midnight in some engines — normalize.
  const n = Number(hour);
  return n === 24 ? 0 : n;
}

/**
 * Week identity for Sunday digests: the Jakarta Sunday date of the current week.
 * Mon–Sat map back to the previous Sunday.
 */
export function jakartaDigestWeekStart(at: Date = new Date()): string {
  const today = jakartaDateString(at);
  const wd = jakartaWeekday(at); // 0=Sun
  if (wd === 0) return today;
  const noonUtc = new Date(`${today}T12:00:00+07:00`);
  noonUtc.setUTCDate(noonUtc.getUTCDate() - wd);
  return jakartaDateString(noonUtc);
}

export function isDigestSendWindow(at: Date = new Date()): boolean {
  if (jakartaWeekday(at) !== 0) return false;
  const hour = jakartaHour(at);
  return hour === config.WEEKLY_DIGEST_HOUR;
}

async function weekHasUsage(childId: string): Promise<boolean> {
  const result = await pool.query<{ n: number }>(
    `SELECT COUNT(*)::int AS n
     FROM usage_telemetry
     WHERE child_id = $1
       AND kind = 'usage'
       AND recorded_at >=
         (date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')
           - interval '6 days'
       AND duration_seconds > 0`,
    [childId],
  );
  return (result.rows[0]?.n ?? 0) > 0;
}

async function kabarCountLast7Days(childId: string): Promise<number> {
  const result = await pool.query<{ n: number }>(
    `SELECT COUNT(*)::int AS n
     FROM audit_events
     WHERE subject_child_id = $1
       AND action = 'child.message'
       AND created_at >=
         (date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')
           - interval '6 days'`,
    [childId],
  );
  return result.rows[0]?.n ?? 0;
}

export function composeDigestNotification(children: DigestChildSummary[]): {
  title: string;
  body: string;
  primaryChildId: string;
} {
  if (children.length === 1) {
    const c = children[0];
    return {
      title: `Ringkasan minggu ini · ${c.childName}`,
      body: `${c.streakText} · ${c.kabarCount} kabar minggu ini.`,
      primaryChildId: c.childId,
    };
  }
  const lines = children.map(
    (c) => `${c.childName}: ${c.streakText} · ${c.kabarCount} kabar`,
  );
  return {
    title: `Ringkasan minggu ini · ${children.length} anak`,
    body: lines.join(' · '),
    primaryChildId: children[0].childId,
  };
}

async function buildChildSummary(childId: string, childName: string): Promise<DigestChildSummary | null> {
  const hasUsageData = await weekHasUsage(childId);
  if (!hasUsageData) return null;

  const [insight, kabarCount] = await Promise.all([
    getOrCreateScreenTimeInsight(childId, 'id'),
    kabarCountLast7Days(childId),
  ]);

  return {
    childId,
    childName: (childName ?? '').trim() || 'Anak',
    streakText: insight.streakText,
    kabarCount,
    hasUsageData: true,
  };
}

async function alreadySent(parentId: string, weekStart: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM weekly_digest_log
     WHERE parent_id = $1 AND week_start_date = $2::date
     LIMIT 1`,
    [parentId, weekStart],
  );
  return (result.rowCount ?? 0) > 0;
}

async function processParent(
  parentId: string,
  children: { childId: string; childName: string }[],
  weekStart: string,
): Promise<boolean> {
  if (await alreadySent(parentId, weekStart)) return false;

  const summaries: DigestChildSummary[] = [];
  for (const child of children) {
    const summary = await buildChildSummary(child.childId, child.childName);
    if (summary) summaries.push(summary);
  }
  if (summaries.length === 0) return false;

  const notif = composeDigestNotification(summaries);

  // Claim the week slot first so a restart cannot double-send.
  const claimed = await pool.query<{ id: string }>(
    `INSERT INTO weekly_digest_log
       (parent_id, week_start_date, payload, primary_child_id)
     VALUES ($1, $2::date, $3::jsonb, $4)
     ON CONFLICT (parent_id, week_start_date) DO NOTHING
     RETURNING id`,
    [
      parentId,
      weekStart,
      JSON.stringify({ children: summaries, title: notif.title, body: notif.body }),
      notif.primaryChildId,
    ],
  );
  if (!claimed.rowCount) return false;

  const data: Record<string, string> = {
    type: 'weekly_digest',
    childId: notif.primaryChildId,
    weekStartDate: weekStart,
    route: 'child_detail',
    digestId: claimed.rows[0].id,
  };

  await sendFcmToUser(parentId, { title: notif.title, body: notif.body }, data);

  broadcastToRoom(parentRoom(parentId), 'parent:weekly_digest', {
    digestId: claimed.rows[0].id,
    weekStartDate: weekStart,
    primaryChildId: notif.primaryChildId,
    title: notif.title,
    body: notif.body,
    children: summaries,
  });

  return true;
}

/** Scan all parent–child pairs and send one batched digest per parent when due. */
export async function runWeeklyDigest(now: Date = new Date()): Promise<number> {
  if (!isDigestSendWindow(now)) return 0;

  const weekStart = jakartaDigestWeekStart(now);
  const rows = await pool.query<ParentChildRow>(
    `SELECT pc.parent_id, pc.child_id, u.name AS child_name
     FROM parent_children pc
     JOIN users u ON u.id = pc.child_id
     ORDER BY pc.parent_id, u.name NULLS LAST`,
  );

  const byParent = new Map<string, { childId: string; childName: string }[]>();
  for (const row of rows.rows) {
    const list = byParent.get(row.parent_id) ?? [];
    list.push({
      childId: row.child_id,
      childName: row.child_name ?? 'Anak',
    });
    byParent.set(row.parent_id, list);
  }

  let sent = 0;
  for (const [parentId, children] of byParent) {
    try {
      const ok = await processParent(parentId, children, weekStart);
      if (ok) sent += 1;
    } catch (err) {
      console.error('weekly_digest_parent_failed', parentId, err);
    }
  }
  return sent;
}

export async function getLatestDigestForParent(parentId: string): Promise<{
  id: string;
  weekStartDate: string;
  primaryChildId: string | null;
  title: string;
  body: string;
  children: DigestChildSummary[];
  sentAt: string;
  openedAt: string | null;
} | null> {
  const result = await pool.query<{
    id: string;
    week_start_date: string;
    primary_child_id: string | null;
    payload: {
      children?: DigestChildSummary[];
      title?: string;
      body?: string;
    };
    sent_at: Date;
    opened_at: Date | null;
  }>(
    `SELECT id, week_start_date::text AS week_start_date, primary_child_id,
            payload, sent_at, opened_at
     FROM weekly_digest_log
     WHERE parent_id = $1
     ORDER BY sent_at DESC
     LIMIT 1`,
    [parentId],
  );
  const row = result.rows[0];
  if (!row) return null;
  const payload = row.payload ?? {};
  return {
    id: row.id,
    weekStartDate: row.week_start_date,
    primaryChildId: row.primary_child_id,
    title: payload.title ?? 'Ringkasan minggu ini',
    body: payload.body ?? '',
    children: payload.children ?? [],
    sentAt: new Date(row.sent_at).toISOString(),
    openedAt: row.opened_at ? new Date(row.opened_at).toISOString() : null,
  };
}

export async function markDigestOpened(
  parentId: string,
  digestId: string,
): Promise<boolean> {
  const result = await pool.query(
    `UPDATE weekly_digest_log
     SET opened_at = COALESCE(opened_at, now())
     WHERE id = $1 AND parent_id = $2
     RETURNING id`,
    [digestId, parentId],
  );
  return (result.rowCount ?? 0) > 0;
}
