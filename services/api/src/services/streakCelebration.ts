import { pool } from '../db/pool.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';
import { awardReward } from './rewards.js';
import {
  celebrationCopy,
  computeConsecutiveUnderLimitDays,
  milestoneAccentTier,
  milestoneBonusPoints,
  nextMilestoneToCelebrate,
  reasonForMilestone,
  type StreakMilestone,
} from './streakCelebrationLogic.js';
import type { DayTotal } from './screentimeInsightLogic.js';

export type PendingStreakCelebration = {
  id: string;
  milestoneDays: StreakMilestone;
  pointsAwarded: number;
  streakStartDate: string;
  accent: 'routine' | 'gold';
  titleId: string;
  bodyId: string;
  titleEn: string;
  bodyEn: string;
  celebratedAt: string;
};

type CelebrationRow = {
  id: string;
  milestone_days: number;
  points_awarded: number;
  streak_start_date: string;
  title_id: string;
  body_id: string;
  title_en: string;
  body_en: string;
  celebrated_at: Date;
};

async function loadLimitMinutes(childId: string): Promise<number> {
  const result = await pool.query<{ daily_limit_minutes: number | null }>(
    `SELECT daily_limit_minutes FROM device_policies
     WHERE child_id = $1
     ORDER BY version DESC
     LIMIT 1`,
    [childId],
  );
  return result.rows[0]?.daily_limit_minutes ?? 180;
}

/** Last N Jakarta calendar days (oldest → newest), zeros when no telemetry. */
async function loadRecentDays(childId: string, dayCount: number): Promise<DayTotal[]> {
  const endOffset = 0;
  const startOffset = Math.max(0, dayCount - 1);
  const result = await pool.query<{ day: string; total_seconds: number }>(
    `WITH days AS (
       SELECT generate_series(
         (date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')
           - ($2::integer * interval '1 day'),
         (date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') AT TIME ZONE 'Asia/Jakarta')
           - ($3::integer * interval '1 day'),
         interval '1 day'
       ) AS day_start
     )
     SELECT to_char(d.day_start AT TIME ZONE 'Asia/Jakarta', 'YYYY-MM-DD') AS day,
            COALESCE(SUM(t.duration_seconds), 0)::integer AS total_seconds
     FROM days d
     LEFT JOIN usage_telemetry t
       ON t.child_id = $1
      AND t.kind = 'usage'
      AND t.recorded_at >= d.day_start
      AND t.recorded_at < d.day_start + interval '1 day'
     GROUP BY d.day_start
     ORDER BY d.day_start`,
    [childId, startOffset, endOffset],
  );
  return result.rows.map((row) => ({
    day: row.day,
    totalSeconds: Number(row.total_seconds) || 0,
  }));
}

function rowToPending(row: CelebrationRow): PendingStreakCelebration {
  const milestone = row.milestone_days as StreakMilestone;
  return {
    id: row.id,
    milestoneDays: milestone,
    pointsAwarded: row.points_awarded,
    streakStartDate:
      typeof row.streak_start_date === 'string'
        ? row.streak_start_date
        : String(row.streak_start_date),
    accent: milestoneAccentTier(milestone),
    titleId: row.title_id,
    bodyId: row.body_id,
    titleEn: row.title_en,
    bodyEn: row.body_en,
    celebratedAt: new Date(row.celebrated_at).toISOString(),
  };
}

/**
 * After usage telemetry lands, check whether a consecutive under-limit streak
 * has crossed a milestone. Awards Rewards points once per streak run and
 * broadcasts a WS event for the child full-screen moment.
 */
export async function checkAndCelebrateStreak(
  childId: string,
): Promise<PendingStreakCelebration | null> {
  const [limitMinutes, days] = await Promise.all([
    loadLimitMinutes(childId),
    loadRecentDays(childId, 40),
  ]);
  const limitSeconds = Math.max(0, limitMinutes) * 60;
  const streak = computeConsecutiveUnderLimitDays(days, limitSeconds);
  if (!streak.hasUsageData || !streak.streakStartDate || streak.consecutiveDays < 3) {
    return null;
  }

  const celebrated = await pool.query<{ milestone_days: number }>(
    `SELECT milestone_days FROM streak_celebrations
     WHERE child_id = $1 AND streak_start_date = $2::date`,
    [childId, streak.streakStartDate],
  );
  const milestone = nextMilestoneToCelebrate(
    streak.consecutiveDays,
    celebrated.rows.map((r) => r.milestone_days),
  );
  if (!milestone) return null;

  const points = milestoneBonusPoints(milestone);
  const copyId = celebrationCopy(milestone, points, 'id');
  const copyEn = celebrationCopy(milestone, points, 'en');
  const reason = reasonForMilestone(milestone, 'id');
  const referenceKey = `streak-milestone:${childId}:${streak.streakStartDate}:${milestone}`;

  const awarded = await awardReward({
    childId,
    delta: points,
    reason,
    referenceKey,
    metadata: {
      kind: 'streak_milestone',
      milestoneDays: milestone,
      streakStartDate: streak.streakStartDate,
      consecutiveDays: streak.consecutiveDays,
    },
  });

  // Even if ledger already had this key (retry), still ensure celebration row.
  const inserted = await pool.query<CelebrationRow>(
    `INSERT INTO streak_celebrations
       (child_id, streak_start_date, milestone_days, points_awarded,
        title_id, body_id, title_en, body_en)
     VALUES ($1, $2::date, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (child_id, streak_start_date, milestone_days) DO NOTHING
     RETURNING id, milestone_days, points_awarded, streak_start_date::text AS streak_start_date,
               title_id, body_id, title_en, body_en, celebrated_at`,
    [
      childId,
      streak.streakStartDate,
      milestone,
      points,
      copyId.title,
      copyId.body,
      copyEn.title,
      copyEn.body,
    ],
  );

  let pending: PendingStreakCelebration | null = null;
  if (inserted.rowCount && inserted.rows[0]) {
    pending = rowToPending(inserted.rows[0]);
  } else {
    const existing = await pool.query<CelebrationRow>(
      `SELECT id, milestone_days, points_awarded, streak_start_date::text AS streak_start_date,
              title_id, body_id, title_en, body_en, celebrated_at
       FROM streak_celebrations
       WHERE child_id = $1 AND streak_start_date = $2::date AND milestone_days = $3
         AND shown_at IS NULL
       LIMIT 1`,
      [childId, streak.streakStartDate, milestone],
    );
    if (existing.rows[0]) pending = rowToPending(existing.rows[0]);
  }

  if (pending) {
    broadcastToRoom(childRoom(childId), 'streak:celebration', {
      childId,
      celebrationId: pending.id,
      milestoneDays: pending.milestoneDays,
      pointsAwarded: pending.pointsAwarded,
      accent: pending.accent,
      titleId: pending.titleId,
      bodyId: pending.bodyId,
      titleEn: pending.titleEn,
      bodyEn: pending.bodyEn,
      awarded,
    });
  }

  return pending;
}

export async function getPendingStreakCelebration(
  childId: string,
): Promise<PendingStreakCelebration | null> {
  const result = await pool.query<CelebrationRow>(
    `SELECT id, milestone_days, points_awarded, streak_start_date::text AS streak_start_date,
            title_id, body_id, title_en, body_en, celebrated_at
     FROM streak_celebrations
     WHERE child_id = $1 AND shown_at IS NULL
     ORDER BY celebrated_at ASC
     LIMIT 1`,
    [childId],
  );
  if (!result.rows[0]) return null;
  return rowToPending(result.rows[0]);
}

export async function ackStreakCelebration(
  childId: string,
  celebrationId: string,
): Promise<boolean> {
  const result = await pool.query(
    `UPDATE streak_celebrations
     SET shown_at = COALESCE(shown_at, now())
     WHERE id = $1 AND child_id = $2
     RETURNING id`,
    [celebrationId, childId],
  );
  return (result.rowCount ?? 0) > 0;
}
