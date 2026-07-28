import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildTemplateInsight,
  classifyPeakCategory,
  classifyStreak,
  classifyTrend,
  computeInsightStats,
  detectPeakUsage,
  detectWeekdayPattern,
  formatPercentChange,
  suggestReminderBeforePeakEnd,
  type InsightStats,
} from './screentimeInsightLogic.js';
import { phraseInsightForTests } from './screentimeInsights.js';

describe('detectPeakUsage', () => {
  it('picks the busiest app and a 2-hour window', () => {
    const peak = detectPeakUsage([
      { packageName: 'com.whatsapp', appLabel: 'WhatsApp', hour: 21, durationSeconds: 2400 },
      { packageName: 'com.whatsapp', appLabel: 'WhatsApp', hour: 22, durationSeconds: 1800 },
      { packageName: 'com.instagram.android', appLabel: 'Instagram', hour: 12, durationSeconds: 900 },
    ]);
    assert.equal(peak.topApp, 'WhatsApp');
    assert.equal(peak.peakStartHour, 21);
    assert.equal(peak.peakEndHour, 23);
  });

  it('returns nulls when empty', () => {
    const peak = detectPeakUsage([]);
    assert.equal(peak.topApp, null);
    assert.equal(peak.peakStartHour, null);
  });
});

describe('classifyPeakCategory', () => {
  it('maps late-night and morning windows', () => {
    assert.equal(classifyPeakCategory(21, 23), 'lateNight');
    assert.equal(classifyPeakCategory(17, 19), 'evening');
    assert.equal(classifyPeakCategory(13, 15), 'afternoon');
    assert.equal(classifyPeakCategory(7, 9), 'morning');
  });
});

describe('suggestReminderBeforePeakEnd', () => {
  it('suggests 15 minutes before peak end', () => {
    assert.equal(suggestReminderBeforePeakEnd(23), '22:45');
  });
});

describe('classifyTrend / classifyStreak', () => {
  it('applies documented thresholds', () => {
    assert.equal(classifyTrend(25), 'up_significant');
    assert.equal(classifyTrend(10), 'up_slight');
    assert.equal(classifyTrend(0), 'stable');
    assert.equal(classifyTrend(-10), 'down_slight');
    assert.equal(classifyTrend(-25), 'down_significant');
    assert.equal(classifyStreak(5, 7), 'high');
    assert.equal(classifyStreak(3, 7), 'moderate');
    assert.equal(classifyStreak(1, 7), 'low');
  });
});

describe('computeInsightStats', () => {
  it('computes projection, trend, peak, and streak deterministically', () => {
    const stats = computeInsightStats({
      childName: 'Budi',
      todaySeconds: 90 * 60,
      limitMinutes: 120,
      weekDays: [
        { day: '2026-07-22', totalSeconds: 60 * 60 },
        { day: '2026-07-23', totalSeconds: 80 * 60 },
        { day: '2026-07-24', totalSeconds: 100 * 60 },
        { day: '2026-07-25', totalSeconds: 150 * 60 },
        { day: '2026-07-26', totalSeconds: 70 * 60 },
        { day: '2026-07-27', totalSeconds: 90 * 60 },
        { day: '2026-07-28', totalSeconds: 90 * 60 },
      ],
      priorWeekDays: [
        { day: '2026-07-15', totalSeconds: 40 * 60 },
        { day: '2026-07-16', totalSeconds: 40 * 60 },
        { day: '2026-07-17', totalSeconds: 40 * 60 },
        { day: '2026-07-18', totalSeconds: 40 * 60 },
        { day: '2026-07-19', totalSeconds: 40 * 60 },
        { day: '2026-07-20', totalSeconds: 40 * 60 },
        { day: '2026-07-21', totalSeconds: 40 * 60 },
      ],
      hourly: [
        { packageName: 'com.whatsapp', appLabel: 'WhatsApp', hour: 21, durationSeconds: 2000 },
        { packageName: 'com.whatsapp', appLabel: 'WhatsApp', hour: 22, durationSeconds: 1500 },
      ],
      now: new Date('2026-07-28T12:00:00+07:00'),
      locale: 'id',
    });
    assert.equal(stats.daysUnderLimit, 6);
    assert.equal(stats.totalDays, 7);
    assert.equal(stats.hasPeakData, true);
    assert.equal(stats.topApp, 'WhatsApp');
    assert.equal(stats.peakStart, '21:00');
    assert.equal(stats.peakCategory, 'lateNight');
    assert.equal(stats.streakCategory, 'high');
    assert.ok(stats.projectedHours > 0);
    assert.ok(stats.percentChange != null && stats.percentChange > 20);
    assert.equal(stats.trendCategory, 'up_significant');
  });
});

describe('detectWeekdayPattern', () => {
  it('omits when fewer than 3 weeks of history', () => {
    const result = detectWeekdayPattern(
      [
        { day: '2026-07-20', totalSeconds: 100 },
        { day: '2026-07-21', totalSeconds: 100 },
        { day: '2026-07-22', totalSeconds: 500 },
      ],
      'id',
    );
    assert.equal(result.category, null);
  });

  it('detects a recurring weekday high across 3+ weeks', () => {
    const days: { day: string; totalSeconds: number }[] = [];
    // Three Mondays (dow=1) elevated; other days flat.
    const mondays = ['2026-07-06', '2026-07-13', '2026-07-20'];
    for (let i = 0; i < 21; i++) {
      const d = new Date(Date.UTC(2026, 6, 6 + i));
      const iso = d.toISOString().slice(0, 10);
      const isMonday = mondays.includes(iso);
      days.push({ day: iso, totalSeconds: isMonday ? 3600 : 600 });
    }
    const result = detectWeekdayPattern(days, 'id');
    assert.equal(result.category, 'weekday_high');
    assert.match(result.dayNames ?? '', /Senin/);
    assert.ok(result.weekCount >= 3);
  });
});

describe('buildTemplateInsight', () => {
  const baseStats: InsightStats = {
    childName: 'Budi',
    todayMinutes: 90,
    limitMinutes: 120,
    avgMinutes: 85,
    priorAvgMinutes: 40,
    percentChange: 112,
    daysUnderLimit: 6,
    totalDays: 7,
    topApp: 'WhatsApp',
    peakStart: '21:00',
    peakEnd: '23:00',
    peakStartHour: 21,
    peakEndHour: 23,
    peakCategory: 'lateNight',
    projectedHours: 85,
    hasPeakData: true,
    weekdayPatternCategory: null,
    weekdayDayNames: null,
    weekCount: 2,
    streakCategory: 'high',
    trendCategory: 'up_significant',
  };

  it('fills placeholders from template JSON (id + en)', () => {
    const id = buildTemplateInsight(baseStats, 'id', undefined, () => 0);
    assert.match(id.phrasing.trendText, /85/);
    assert.match(id.phrasing.trendText, /bulan ini/);
    assert.match(id.phrasing.patternText ?? '', /WhatsApp/);
    assert.match(id.phrasing.patternText ?? '', /21:00/);
    assert.equal(id.phrasing.patternDayText, null);
    assert.match(id.phrasing.streakText, /6/);
    assert.equal(id.phrasing.suggestedReminderTime, '22:45');
    assert.ok(id.phrasing.suggestedReminderLabel);

    const en = buildTemplateInsight(baseStats, 'en', id.pick);
    assert.match(en.phrasing.trendText, /this month/);
    assert.match(en.phrasing.patternText ?? '', /WhatsApp/);
  });

  it('omits peak and reminder for morning peaks', () => {
    const morning: InsightStats = {
      ...baseStats,
      peakCategory: 'morning',
      peakStart: '07:00',
      peakEnd: '09:00',
      peakStartHour: 7,
      peakEndHour: 9,
    };
    const built = buildTemplateInsight(morning, 'id', undefined, () => 0);
    assert.match(built.phrasing.patternText ?? '', /pagi|07:00/);
    assert.equal(built.phrasing.suggestedReminderTime, null);
    assert.equal(built.phrasing.suggestedReminderLabel, null);
  });

  it('omits peakHour line when no peak data', () => {
    const noPeak: InsightStats = {
      ...baseStats,
      hasPeakData: false,
      topApp: null,
      peakStart: null,
      peakEnd: null,
      peakStartHour: null,
      peakEndHour: null,
      peakCategory: null,
    };
    const built = buildTemplateInsight(noPeak, 'id', undefined, () => 0);
    assert.equal(built.phrasing.patternText, null);
    assert.equal(built.phrasing.suggestedReminderTime, null);
  });

  it('stable pick yields identical wording for same indices', () => {
    const a = phraseInsightForTests(baseStats, 'id', undefined, () => 0.2);
    const b = phraseInsightForTests(baseStats, 'id', a.pick);
    assert.equal(a.phrasing.trendText, b.phrasing.trendText);
    assert.equal(a.phrasing.patternText, b.phrasing.patternText);
    assert.equal(a.phrasing.streakText, b.phrasing.streakText);
    assert.equal(a.source, 'template');
  });

  it('formats percent without sign (template supplies naik/turun)', () => {
    assert.equal(formatPercentChange(-18), '18%');
    assert.equal(formatPercentChange(23), '23%');
  });
});
