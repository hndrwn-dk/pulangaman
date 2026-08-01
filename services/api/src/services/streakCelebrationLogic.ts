import type { DayTotal } from './screentimeInsightLogic.js';

export const STREAK_MILESTONES = [3, 7, 14, 30] as const;
export type StreakMilestone = (typeof STREAK_MILESTONES)[number];

export type ConsecutiveStreak = {
  consecutiveDays: number;
  streakStartDate: string | null;
  hasUsageData: boolean;
};

/** Bonus points by milestone — ties celebration to Rewards ledger. */
export function milestoneBonusPoints(days: StreakMilestone): number {
  switch (days) {
    case 3:
      return 5;
    case 7:
      return 10;
    case 14:
      return 15;
    case 30:
      return 25;
    default:
      return 0;
  }
}

export function reasonForMilestone(days: StreakMilestone, locale: 'id' | 'en' = 'id'): string {
  if (locale === 'en') {
    return `${days}-day streak bonus`;
  }
  return `Bonus streak ${days} hari`;
}

/**
 * Walk newest → oldest. Days at/under the daily limit continue the streak;
 * an over-limit day breaks it. Requires at least one day with usage > 0 so a
 * brand-new child with an all-zero generate_series window does not celebrate.
 */
export function computeConsecutiveUnderLimitDays(
  days: DayTotal[],
  limitSeconds: number,
): ConsecutiveStreak {
  if (days.length === 0) {
    return { consecutiveDays: 0, streakStartDate: null, hasUsageData: false };
  }

  const hasUsageData = days.some((d) => d.totalSeconds > 0);
  if (!hasUsageData) {
    return { consecutiveDays: 0, streakStartDate: null, hasUsageData: false };
  }

  let consecutiveDays = 0;
  let streakStartDate: string | null = null;
  for (let i = days.length - 1; i >= 0; i -= 1) {
    const day = days[i];
    const under = limitSeconds <= 0 || day.totalSeconds <= limitSeconds;
    if (!under) break;
    consecutiveDays += 1;
    streakStartDate = day.day;
  }

  return { consecutiveDays, streakStartDate, hasUsageData };
}

/** Lowest uncelebrated milestone that the current streak has reached. */
export function nextMilestoneToCelebrate(
  consecutiveDays: number,
  alreadyCelebrated: Iterable<number>,
): StreakMilestone | null {
  const done = new Set(alreadyCelebrated);
  for (const m of STREAK_MILESTONES) {
    if (consecutiveDays >= m && !done.has(m)) {
      return m;
    }
  }
  return null;
}

export function celebrationCopy(
  days: StreakMilestone,
  _points: number,
  locale: 'id' | 'en',
): { title: string; body: string } {
  if (locale === 'en') {
    return {
      title: `${days}-Day Streak!`,
      body: `You've kept your screen time on target for ${days} days. Nice work!`,
    };
  }
  return {
    title: `${days} Hari Berturut-turut!`,
    body: `Kamu jaga waktu layar sesuai target selama ${days} hari. Mantap!`,
  };
}

/** Accent for native moment UI — bedtime gold for every streak milestone. */
export function milestoneAccentTier(_days: StreakMilestone): 'routine' | 'gold' {
  return 'gold';
}
