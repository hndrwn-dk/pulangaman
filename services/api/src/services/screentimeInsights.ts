import { pool } from '../db/pool.js';
import {
  buildTemplateInsight,
  computeInsightStats,
  normalizeLocale,
  type DayTotal,
  type HourlyBucket,
  type InsightLocale,
  type InsightPhrasing,
  type InsightStats,
  type TemplatePick,
} from './screentimeInsightLogic.js';

export type StoredInsight = InsightPhrasing & {
  daysUnderLimit: number;
  totalDays: number;
  source: 'template' | 'cache';
  date: string;
  generatedAt: string;
  locale: InsightLocale;
};

type CacheRow = {
  date: string;
  trend_text: string;
  pattern_text: string | null;
  pattern_day_text: string | null;
  streak_text: string;
  suggested_reminder_time: string | null;
  suggested_reminder_label: string | null;
  days_under_limit: number;
  total_days: number;
  source: string;
  generated_at: Date;
  locale: string | null;
};

function jakartaToday(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

async function loadChildName(childId: string): Promise<string> {
  const result = await pool.query<{ name: string | null }>(
    `SELECT name FROM users WHERE id = $1`,
    [childId],
  );
  return (result.rows[0]?.name ?? '').trim() || 'Anak';
}

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

async function loadDayRange(
  childId: string,
  startOffsetDays: number,
  endOffsetDays: number,
): Promise<DayTotal[]> {
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
    [childId, startOffsetDays, endOffsetDays],
  );
  return result.rows.map((row) => ({
    day: row.day,
    totalSeconds: Number(row.total_seconds) || 0,
  }));
}

async function loadTodaySeconds(childId: string): Promise<number> {
  const result = await pool.query<{ total: number }>(
    `SELECT COALESCE(SUM(duration_seconds), 0)::integer AS total
     FROM usage_telemetry
     WHERE child_id = $1
       AND kind = 'usage'
       AND recorded_at >= (
         date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta')
         AT TIME ZONE 'Asia/Jakarta'
       )`,
    [childId],
  );
  return Number(result.rows[0]?.total) || 0;
}

async function loadHourlyBuckets(childId: string): Promise<HourlyBucket[]> {
  const result = await pool.query<{
    package_name: string | null;
    app_label: string | null;
    hour: number | null;
    duration_seconds: number;
  }>(
    `SELECT package_name,
            MAX(payload->>'appLabel') AS app_label,
            COALESCE(
              (payload->>'hour')::integer,
              EXTRACT(HOUR FROM recorded_at AT TIME ZONE 'Asia/Jakarta')::integer
            ) AS hour,
            SUM(COALESCE(duration_seconds, 0))::integer AS duration_seconds
     FROM usage_telemetry
     WHERE child_id = $1
       AND kind = 'usage_hourly'
       AND recorded_at >= now() - interval '7 days'
     GROUP BY package_name, hour
     HAVING SUM(COALESCE(duration_seconds, 0)) > 0`,
    [childId],
  );
  return result.rows
    .filter((row) => row.package_name && row.hour != null)
    .map((row) => ({
      packageName: row.package_name as string,
      appLabel: row.app_label,
      hour: Number(row.hour),
      durationSeconds: Number(row.duration_seconds) || 0,
    }));
}

function rowToStored(row: CacheRow, source: StoredInsight['source']): StoredInsight {
  return {
    trendText: row.trend_text,
    patternText: row.pattern_text,
    patternDayText: row.pattern_day_text,
    streakText: row.streak_text,
    suggestedReminderTime: row.suggested_reminder_time,
    suggestedReminderLabel: row.suggested_reminder_label,
    daysUnderLimit: row.days_under_limit,
    totalDays: row.total_days,
    source,
    date: typeof row.date === 'string' ? row.date : String(row.date),
    generatedAt: new Date(row.generated_at).toISOString(),
    locale: normalizeLocale(row.locale),
  };
}

const SELECT_COLS = `date::text AS date, trend_text, pattern_text, pattern_day_text, streak_text,
            suggested_reminder_time, suggested_reminder_label,
            days_under_limit, total_days, source, generated_at, locale`;

/**
 * Parent Screen Time insights — cache once per child per Jakarta calendar day.
 * Stats and phrasing are fully local (template JSON); no external LLM call.
 */
export async function getOrCreateScreenTimeInsight(
  childId: string,
  localeRaw?: string | null,
): Promise<StoredInsight> {
  const date = jakartaToday();
  const locale = normalizeLocale(localeRaw);

  const cached = await pool.query<CacheRow>(
    `SELECT ${SELECT_COLS}
     FROM screentime_insights
     WHERE child_id = $1 AND date = $2::date`,
    [childId, date],
  );
  if (cached.rowCount && cached.rows[0]) {
    return rowToStored(cached.rows[0], 'cache');
  }

  const [childName, limitMinutes, weekDays, priorWeekDays, historyDays, todaySeconds, hourly] =
    await Promise.all([
      loadChildName(childId),
      loadLimitMinutes(childId),
      loadDayRange(childId, 6, 0),
      loadDayRange(childId, 13, 7),
      loadDayRange(childId, 27, 0),
      loadTodaySeconds(childId),
      loadHourlyBuckets(childId),
    ]);

  const stats = computeInsightStats({
    childName,
    todaySeconds,
    limitMinutes,
    weekDays,
    priorWeekDays,
    historyDays,
    hourly,
    locale,
  });

  const { phrasing, pick } = buildTemplateInsight(stats, locale);
  const source = 'template' as const;

  const inserted = await pool.query<CacheRow>(
    `INSERT INTO screentime_insights
       (child_id, date, trend_text, pattern_text, pattern_day_text, streak_text,
        suggested_reminder_time, suggested_reminder_label,
        days_under_limit, total_days, stats_snapshot, source, locale)
     VALUES ($1, $2::date, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12, $13)
     ON CONFLICT (child_id, date) DO NOTHING
     RETURNING ${SELECT_COLS}`,
    [
      childId,
      date,
      phrasing.trendText,
      phrasing.patternText,
      phrasing.patternDayText,
      phrasing.streakText,
      phrasing.suggestedReminderTime,
      phrasing.suggestedReminderLabel,
      stats.daysUnderLimit,
      stats.totalDays,
      JSON.stringify({ stats, templatePick: pick, locale }),
      source,
      locale,
    ],
  );

  if (inserted.rowCount && inserted.rows[0]) {
    return rowToStored(inserted.rows[0], source);
  }

  const again = await pool.query<CacheRow>(
    `SELECT ${SELECT_COLS}
     FROM screentime_insights
     WHERE child_id = $1 AND date = $2::date`,
    [childId, date],
  );
  if (again.rows[0]) {
    return rowToStored(again.rows[0], 'cache');
  }

  return {
    ...phrasing,
    daysUnderLimit: stats.daysUnderLimit,
    totalDays: stats.totalDays,
    source,
    date,
    generatedAt: new Date().toISOString(),
    locale,
  };
}

/** Test seam — build phrasing from stats with an optional fixed RNG / pick. */
export function phraseInsightForTests(
  stats: InsightStats,
  locale: InsightLocale = 'id',
  pick?: TemplatePick,
  rng?: () => number,
): { phrasing: InsightPhrasing; pick: TemplatePick; source: 'template' } {
  const built = buildTemplateInsight(stats, locale, pick, rng ?? (() => 0));
  return { ...built, source: 'template' };
}
