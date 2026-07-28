import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export type InsightLocale = 'id' | 'en';

export type HourlyBucket = {
  packageName: string;
  appLabel: string | null;
  hour: number;
  durationSeconds: number;
};

export type DayTotal = {
  day: string;
  totalSeconds: number;
};

export type PeakCategory = 'lateNight' | 'evening' | 'afternoon' | 'morning';
export type TrendCategory =
  | 'up_significant'
  | 'up_slight'
  | 'stable'
  | 'down_slight'
  | 'down_significant';
export type WeekdayPatternCategory = 'weekday_high' | 'weekend_high';
export type StreakCategory = 'high' | 'moderate' | 'low';

export type InsightStats = {
  childName: string;
  todayMinutes: number;
  limitMinutes: number;
  avgMinutes: number;
  priorAvgMinutes: number | null;
  percentChange: number | null;
  daysUnderLimit: number;
  totalDays: number;
  topApp: string | null;
  peakStart: string | null;
  peakEnd: string | null;
  peakStartHour: number | null;
  peakEndHour: number | null;
  peakCategory: PeakCategory | null;
  projectedHours: number;
  hasPeakData: boolean;
  weekdayPatternCategory: WeekdayPatternCategory | null;
  weekdayDayNames: string | null;
  weekCount: number;
  streakCategory: StreakCategory;
  trendCategory: TrendCategory;
};

export type InsightPhrasing = {
  trendText: string;
  patternText: string | null;
  patternDayText: string | null;
  streakText: string;
  suggestedReminderTime: string | null;
  suggestedReminderLabel: string | null;
};

export type TemplatePick = {
  trend: number;
  peakHour: number | null;
  weekdayPattern: number | null;
  streak: number;
  reminderLabel: number | null;
};

type LangBundle = { id: string[]; en: string[] };

type TemplatesFile = {
  trend: Record<string, LangBundle | unknown>;
  peakHour: Record<string, LangBundle | unknown>;
  weekdayPattern: Record<string, LangBundle | unknown>;
  streak: Record<string, LangBundle | unknown>;
  reminderLabel: LangBundle;
};

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadTemplates(): TemplatesFile {
  const candidates = [
    path.join(__dirname, '../data/screentime-insight-templates.json'),
    path.join(__dirname, '../../src/data/screentime-insight-templates.json'),
  ];
  for (const candidate of candidates) {
    try {
      return JSON.parse(readFileSync(candidate, 'utf8')) as TemplatesFile;
    } catch {
      // try next
    }
  }
  throw new Error('screentime_insight_templates_missing');
}

const templates = loadTemplates();

function pad2(n: number): string {
  return n.toString().padStart(2, '0');
}

export function formatHourLabel(hour: number): string {
  const h = ((hour % 24) + 24) % 24;
  return `${pad2(h)}:00`;
}

export function normalizeLocale(raw: string | undefined | null): InsightLocale {
  const code = (raw ?? 'id').trim().toLowerCase();
  return code.startsWith('en') ? 'en' : 'id';
}

/** Wind-down ~15 minutes before the peak window ends. */
export function suggestReminderBeforePeakEnd(peakEndHour: number): string {
  const end = ((peakEndHour % 24) + 24) % 24;
  let minuteTotal = end * 60 - 15;
  if (minuteTotal < 0) minuteTotal += 24 * 60;
  const hour = Math.floor(minuteTotal / 60) % 24;
  const minute = minuteTotal % 60;
  return `${pad2(hour)}:${pad2(minute)}`;
}

/**
 * Classify a peak window by which band it overlaps most.
 * lateNight 21-24, evening 17-21, afternoon 12-17, morning 05-12.
 */
export function classifyPeakCategory(
  startHour: number,
  endHour: number,
): PeakCategory {
  const bands: Array<{ key: PeakCategory; start: number; end: number }> = [
    { key: 'lateNight', start: 21, end: 24 },
    { key: 'evening', start: 17, end: 21 },
    { key: 'afternoon', start: 12, end: 17 },
    { key: 'morning', start: 5, end: 12 },
  ];

  const start = ((startHour % 24) + 24) % 24;
  let end = ((endHour % 24) + 24) % 24;
  if (end <= start) end += 24;

  let best: PeakCategory = 'evening';
  let bestOverlap = -1;
  for (const band of bands) {
    const overlap = Math.max(
      0,
      Math.min(end, band.end) - Math.max(start, band.start),
    );
    // Prefer later bands on ties (lateNight > evening > …).
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = band.key;
    }
  }
  if (bestOverlap <= 0) {
    const mid = Math.floor((start + Math.min(end, start + 24)) / 2) % 24;
    if (mid >= 21) return 'lateNight';
    if (mid >= 17) return 'evening';
    if (mid >= 12) return 'afternoon';
    if (mid >= 5) return 'morning';
    return 'lateNight';
  }
  return best;
}

/**
 * Find the app with the most hourly usage, then a contiguous peak window
 * around its busiest hour (typically 2 hours, matching the mockup shape).
 */
export function detectPeakUsage(buckets: HourlyBucket[]): {
  topApp: string | null;
  peakStartHour: number | null;
  peakEndHour: number | null;
} {
  if (buckets.length === 0) {
    return { topApp: null, peakStartHour: null, peakEndHour: null };
  }

  const byApp = new Map<string, { label: string; total: number; hours: Map<number, number> }>();
  for (const b of buckets) {
    if (b.durationSeconds <= 0) continue;
    const label = (b.appLabel && b.appLabel.trim()) || b.packageName;
    let entry = byApp.get(b.packageName);
    if (!entry) {
      entry = { label, total: 0, hours: new Map() };
      byApp.set(b.packageName, entry);
    }
    entry.total += b.durationSeconds;
    entry.hours.set(b.hour, (entry.hours.get(b.hour) ?? 0) + b.durationSeconds);
  }

  let bestPkg: string | null = null;
  let bestTotal = 0;
  for (const [pkg, entry] of byApp) {
    if (entry.total > bestTotal) {
      bestTotal = entry.total;
      bestPkg = pkg;
    }
  }
  if (!bestPkg) {
    return { topApp: null, peakStartHour: null, peakEndHour: null };
  }

  const hours = byApp.get(bestPkg)!.hours;
  let peakHour = 0;
  let peakSecs = -1;
  for (const [hour, secs] of hours) {
    if (secs > peakSecs) {
      peakSecs = secs;
      peakHour = hour;
    }
  }

  const next = hours.get((peakHour + 1) % 24) ?? 0;
  const prev = hours.get((peakHour + 23) % 24) ?? 0;
  let startHour = peakHour;
  let endHour = (peakHour + 2) % 24;
  if (prev > next && prev >= peakSecs * 0.4) {
    startHour = (peakHour + 23) % 24;
    endHour = (peakHour + 1) % 24;
  } else if (next >= peakSecs * 0.4) {
    startHour = peakHour;
    endHour = (peakHour + 2) % 24;
  } else {
    startHour = peakHour;
    endHour = (peakHour + 1) % 24;
  }

  return {
    topApp: byApp.get(bestPkg)!.label,
    peakStartHour: startHour,
    peakEndHour: endHour,
  };
}

export function classifyTrend(percentChange: number | null): TrendCategory {
  if (percentChange == null || Number.isNaN(percentChange)) return 'stable';
  if (percentChange > 20) return 'up_significant';
  if (percentChange >= 5) return 'up_slight';
  if (percentChange > -5) return 'stable';
  if (percentChange >= -20) return 'down_slight';
  return 'down_significant';
}

export function classifyStreak(daysUnderLimit: number, totalDays: number): StreakCategory {
  const total = Math.max(1, totalDays);
  const ratio = daysUnderLimit / total;
  if (ratio >= 0.7) return 'high';
  if (ratio >= 0.4) return 'moderate';
  return 'low';
}

function parseDayUtc(day: string): Date {
  // YYYY-MM-DD as Jakarta calendar day — treat as noon UTC to avoid DST edge issues.
  return new Date(`${day}T12:00:00Z`);
}

function jsDow(day: string): number {
  return parseDayUtc(day).getUTCDay(); // 0=Sun … 6=Sat
}

function weekKey(day: string): string {
  const d = parseDayUtc(day);
  // ISO-ish week: Thursday-based year week via UTC.
  const tmp = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((tmp.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${tmp.getUTCFullYear()}-W${pad2(weekNo)}`;
}

const DOW_NAMES: Record<InsightLocale, string[]> = {
  id: ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'],
  en: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
};

export function formatDayNames(dows: number[], locale: InsightLocale): string {
  const names = dows.map((d) => DOW_NAMES[locale][((d % 7) + 7) % 7]);
  if (names.length <= 1) return names[0] ?? '';
  if (names.length === 2) return `${names[0]} & ${names[1]}`;
  return `${names.slice(0, -1).join(', ')} & ${names[names.length - 1]}`;
}

/**
 * weekday_high: 1–2 weekdays >25% above daily average in >=3 of last weekCount weeks.
 * weekend_high: Sat/Sun pair clears the same bar. Omit if neither clears.
 */
export function detectWeekdayPattern(
  days: DayTotal[],
  locale: InsightLocale,
): {
  category: WeekdayPatternCategory | null;
  dayNames: string | null;
  weekCount: number;
} {
  if (days.length === 0) {
    return { category: null, dayNames: null, weekCount: 0 };
  }

  const byWeek = new Map<string, Map<number, number>>();
  let sum = 0;
  for (const d of days) {
    sum += d.totalSeconds;
    const wk = weekKey(d.day);
    let map = byWeek.get(wk);
    if (!map) {
      map = new Map();
      byWeek.set(wk, map);
    }
    const dow = jsDow(d.day);
    map.set(dow, (map.get(dow) ?? 0) + d.totalSeconds);
  }

  const weeks = [...byWeek.keys()].sort();
  const weekCount = weeks.length;
  if (weekCount < 3) {
    return { category: null, dayNames: null, weekCount };
  }

  const dailyAvg = sum / Math.max(1, days.length);
  const threshold = dailyAvg * 1.25;

  const weekdayHighCounts = new Map<number, number>();
  for (let dow = 1; dow <= 5; dow++) weekdayHighCounts.set(dow, 0);

  let weekendHighWeeks = 0;
  for (const wk of weeks) {
    const map = byWeek.get(wk)!;
    for (let dow = 1; dow <= 5; dow++) {
      const secs = map.get(dow) ?? 0;
      if (secs > threshold) {
        weekdayHighCounts.set(dow, (weekdayHighCounts.get(dow) ?? 0) + 1);
      }
    }
    const sat = map.get(6) ?? 0;
    const sun = map.get(0) ?? 0;
    const weekendAvg = (sat + sun) / 2;
    if (weekendAvg > threshold) weekendHighWeeks += 1;
  }

  const strongWeekdays = [...weekdayHighCounts.entries()]
    .filter(([, count]) => count >= 3)
    .sort((a, b) => b[1] - a[1] || a[0] - b[0])
    .slice(0, 2)
    .map(([dow]) => dow);

  if (strongWeekdays.length >= 1) {
    return {
      category: 'weekday_high',
      dayNames: formatDayNames(strongWeekdays, locale),
      weekCount,
    };
  }

  if (weekendHighWeeks >= 3) {
    return {
      category: 'weekend_high',
      dayNames: null,
      weekCount,
    };
  }

  return { category: null, dayNames: null, weekCount };
}

export function computeInsightStats(input: {
  childName: string;
  todaySeconds: number;
  limitMinutes: number;
  weekDays: DayTotal[];
  priorWeekDays?: DayTotal[];
  historyDays?: DayTotal[];
  hourly: HourlyBucket[];
  locale?: InsightLocale;
  now?: Date;
}): InsightStats {
  const now = input.now ?? new Date();
  const locale = input.locale ?? 'id';
  const limitMinutes = Math.max(0, input.limitMinutes);
  const limitSeconds = limitMinutes * 60;
  const days = input.weekDays;
  const totalDays = Math.max(1, days.length || 7);

  let daysUnderLimit = 0;
  let sumSeconds = 0;
  for (const d of days) {
    sumSeconds += d.totalSeconds;
    if (limitSeconds <= 0 || d.totalSeconds <= limitSeconds) {
      daysUnderLimit += 1;
    }
  }

  const avgMinutes = Math.round(sumSeconds / totalDays / 60);

  const prior = input.priorWeekDays ?? [];
  let priorAvgMinutes: number | null = null;
  let percentChange: number | null = null;
  if (prior.length > 0) {
    const priorSum = prior.reduce((s, d) => s + d.totalSeconds, 0);
    priorAvgMinutes = Math.round(priorSum / prior.length / 60);
    if (priorAvgMinutes > 0) {
      percentChange = Math.round(((avgMinutes - priorAvgMinutes) / priorAvgMinutes) * 100);
    } else if (avgMinutes > 0) {
      percentChange = 100;
    } else {
      percentChange = 0;
    }
  }

  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const projectedHours = Math.round((avgMinutes * daysInMonth) / 60);

  const peak = detectPeakUsage(input.hourly);
  const hasPeakData =
    peak.topApp != null && peak.peakStartHour != null && peak.peakEndHour != null;
  const peakCategory = hasPeakData
    ? classifyPeakCategory(peak.peakStartHour!, peak.peakEndHour!)
    : null;

  const weekday = detectWeekdayPattern(input.historyDays ?? days, locale);

  return {
    childName: input.childName,
    todayMinutes: Math.round(input.todaySeconds / 60),
    limitMinutes,
    avgMinutes,
    priorAvgMinutes,
    percentChange,
    daysUnderLimit,
    totalDays,
    topApp: peak.topApp,
    peakStart: hasPeakData ? formatHourLabel(peak.peakStartHour!) : null,
    peakEnd: hasPeakData ? formatHourLabel(peak.peakEndHour!) : null,
    peakStartHour: peak.peakStartHour,
    peakEndHour: peak.peakEndHour,
    peakCategory,
    projectedHours,
    hasPeakData,
    weekdayPatternCategory: weekday.category,
    weekdayDayNames: weekday.dayNames,
    weekCount: weekday.weekCount,
    streakCategory: classifyStreak(daysUnderLimit, totalDays),
    trendCategory: classifyTrend(percentChange),
  };
}

function isLangBundle(value: unknown): value is LangBundle {
  return (
    !!value &&
    typeof value === 'object' &&
    Array.isArray((value as LangBundle).id) &&
    Array.isArray((value as LangBundle).en)
  );
}

function getCategoryBundle(
  section: Record<string, unknown>,
  key: string,
): LangBundle {
  const bundle = section[key];
  if (!isLangBundle(bundle) || bundle.id.length === 0 || bundle.en.length === 0) {
    throw new Error(`insight_template_missing:${key}`);
  }
  return bundle;
}

function substitute(template: string, vars: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (_, key: string) => vars[key] ?? `{${key}}`);
}

function pickVariant(bundle: LangBundle, locale: InsightLocale, index: number): string {
  const list = bundle[locale];
  const i = ((index % list.length) + list.length) % list.length;
  return list[i]!;
}

export function formatPercentChange(value: number): string {
  return `${Math.abs(Math.round(value))}%`;
}

export function formatProjectedValue(hours: number, locale: InsightLocale): string {
  return locale === 'en' ? `${hours} hours` : `${hours} jam`;
}

export function formatPeriodLabel(locale: InsightLocale): string {
  return locale === 'en' ? 'this month' : 'bulan ini';
}

export function chooseTemplateIndices(
  stats: InsightStats,
  rng: () => number = Math.random,
): TemplatePick {
  const trendBundle = getCategoryBundle(
    templates.trend as Record<string, unknown>,
    stats.trendCategory,
  );
  const streakBundle = getCategoryBundle(
    templates.streak as Record<string, unknown>,
    stats.streakCategory,
  );

  const pick = (n: number) => Math.floor(rng() * n);

  const result: TemplatePick = {
    trend: pick(trendBundle.id.length),
    peakHour: null,
    weekdayPattern: null,
    streak: pick(streakBundle.id.length),
    reminderLabel: null,
  };

  if (stats.hasPeakData && stats.peakCategory) {
    const peakBundle = getCategoryBundle(
      templates.peakHour as Record<string, unknown>,
      stats.peakCategory,
    );
    result.peakHour = pick(peakBundle.id.length);
    if (stats.peakCategory === 'lateNight' || stats.peakCategory === 'evening') {
      result.reminderLabel = pick(templates.reminderLabel.id.length);
    }
  }

  if (stats.weekdayPatternCategory) {
    const wdBundle = getCategoryBundle(
      templates.weekdayPattern as Record<string, unknown>,
      stats.weekdayPatternCategory,
    );
    result.weekdayPattern = pick(wdBundle.id.length);
  }

  return result;
}

export function buildTemplateInsight(
  stats: InsightStats,
  locale: InsightLocale = 'id',
  pick?: TemplatePick,
  rng: () => number = Math.random,
): { phrasing: InsightPhrasing; pick: TemplatePick } {
  const indices = pick ?? chooseTemplateIndices(stats, rng);
  const lang = normalizeLocale(locale);

  const trendVars = {
    childName: stats.childName,
    projectedValue: formatProjectedValue(stats.projectedHours, lang),
    percentChange: formatPercentChange(stats.percentChange ?? 0),
    periodLabel: formatPeriodLabel(lang),
  };
  const trendText = substitute(
    pickVariant(
      getCategoryBundle(templates.trend as Record<string, unknown>, stats.trendCategory),
      lang,
      indices.trend,
    ),
    trendVars,
  );

  let patternText: string | null = null;
  if (
    stats.hasPeakData &&
    stats.peakCategory &&
    stats.topApp &&
    stats.peakStart &&
    stats.peakEnd &&
    indices.peakHour != null
  ) {
    patternText = substitute(
      pickVariant(
        getCategoryBundle(templates.peakHour as Record<string, unknown>, stats.peakCategory),
        lang,
        indices.peakHour,
      ),
      {
        appName: stats.topApp,
        startTime: stats.peakStart,
        endTime: stats.peakEnd,
      },
    );
  }

  let patternDayText: string | null = null;
  if (stats.weekdayPatternCategory && indices.weekdayPattern != null) {
    patternDayText = substitute(
      pickVariant(
        getCategoryBundle(
          templates.weekdayPattern as Record<string, unknown>,
          stats.weekdayPatternCategory,
        ),
        lang,
        indices.weekdayPattern,
      ),
      {
        dayNames: stats.weekdayDayNames ?? '',
        weekCount: String(stats.weekCount),
      },
    );
  }

  const streakText = substitute(
    pickVariant(
      getCategoryBundle(templates.streak as Record<string, unknown>, stats.streakCategory),
      lang,
      indices.streak,
    ),
    {
      daysUnderLimit: String(stats.daysUnderLimit),
      totalDays: String(stats.totalDays),
    },
  );

  let suggestedReminderTime: string | null = null;
  let suggestedReminderLabel: string | null = null;
  if (
    (stats.peakCategory === 'lateNight' || stats.peakCategory === 'evening') &&
    stats.peakEndHour != null &&
    indices.reminderLabel != null
  ) {
    suggestedReminderTime = suggestReminderBeforePeakEnd(stats.peakEndHour);
    suggestedReminderLabel = pickVariant(
      templates.reminderLabel,
      lang,
      indices.reminderLabel,
    );
  }

  return {
    phrasing: {
      trendText,
      patternText,
      patternDayText,
      streakText,
      suggestedReminderTime,
      suggestedReminderLabel,
    },
    pick: indices,
  };
}
