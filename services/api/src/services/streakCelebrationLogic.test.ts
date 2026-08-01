import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  celebrationCopy,
  computeConsecutiveUnderLimitDays,
  milestoneBonusPoints,
  nextMilestoneToCelebrate,
} from './streakCelebrationLogic.js';

describe('computeConsecutiveUnderLimitDays', () => {
  it('returns zero when there is no usage data', () => {
    const days = [
      { day: '2026-07-28', totalSeconds: 0 },
      { day: '2026-07-29', totalSeconds: 0 },
      { day: '2026-07-30', totalSeconds: 0 },
    ];
    const result = computeConsecutiveUnderLimitDays(days, 180 * 60);
    assert.equal(result.consecutiveDays, 0);
    assert.equal(result.hasUsageData, false);
  });

  it('counts consecutive under-limit days from the newest day', () => {
    const limit = 180 * 60;
    const days = [
      { day: '2026-07-25', totalSeconds: 200 * 60 },
      { day: '2026-07-26', totalSeconds: 60 * 60 },
      { day: '2026-07-27', totalSeconds: 90 * 60 },
      { day: '2026-07-28', totalSeconds: 100 * 60 },
      { day: '2026-07-29', totalSeconds: 50 * 60 },
      { day: '2026-07-30', totalSeconds: 40 * 60 },
      { day: '2026-07-31', totalSeconds: 30 * 60 },
    ];
    const result = computeConsecutiveUnderLimitDays(days, limit);
    assert.equal(result.consecutiveDays, 6);
    assert.equal(result.streakStartDate, '2026-07-26');
    assert.equal(result.hasUsageData, true);
  });

  it('resets after an over-limit day', () => {
    const limit = 100 * 60;
    const days = [
      { day: '2026-07-28', totalSeconds: 40 * 60 },
      { day: '2026-07-29', totalSeconds: 40 * 60 },
      { day: '2026-07-30', totalSeconds: 200 * 60 },
      { day: '2026-07-31', totalSeconds: 40 * 60 },
    ];
    const result = computeConsecutiveUnderLimitDays(days, limit);
    assert.equal(result.consecutiveDays, 1);
    assert.equal(result.streakStartDate, '2026-07-31');
  });
});

describe('nextMilestoneToCelebrate', () => {
  it('returns the lowest uncelebrated milestone', () => {
    assert.equal(nextMilestoneToCelebrate(7, []), 3);
    assert.equal(nextMilestoneToCelebrate(7, [3]), 7);
    assert.equal(nextMilestoneToCelebrate(7, [3, 7]), null);
    assert.equal(nextMilestoneToCelebrate(30, [3, 7, 14]), 30);
  });
});

describe('milestoneBonusPoints and copy', () => {
  it('awards expected points', () => {
    assert.equal(milestoneBonusPoints(3), 5);
    assert.equal(milestoneBonusPoints(7), 10);
    assert.equal(milestoneBonusPoints(14), 15);
    assert.equal(milestoneBonusPoints(30), 25);
  });

  it('includes milestone days in localized copy', () => {
    const id = celebrationCopy(7, 10, 'id');
    assert.match(id.title, /7/);
    assert.match(id.body, /7 hari/);
    assert.doesNotMatch(id.body, /\+10/);
    const en = celebrationCopy(7, 10, 'en');
    assert.match(en.title, /7-Day/);
    assert.match(en.body, /7 days/);
    assert.doesNotMatch(en.body, /\+10/);
  });
});
