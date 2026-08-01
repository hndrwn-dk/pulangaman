import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  composeDigestNotification,
  jakartaDigestWeekStart,
  isDigestSendWindow,
  jakartaHour,
} from './weeklyDigest.js';

describe('composeDigestNotification', () => {
  it('formats a single-child digest', () => {
    const n = composeDigestNotification([
      {
        childId: 'c1',
        childName: 'Alya',
        streakText: '5 dari 7 hari di bawah batas',
        kabarCount: 3,
        hasUsageData: true,
      },
    ]);
    assert.equal(n.title, 'Ringkasan minggu ini · Alya');
    assert.match(n.body, /5 dari 7/);
    assert.match(n.body, /3 kabar/);
    assert.equal(n.primaryChildId, 'c1');
  });

  it('batches multiple children into one notification', () => {
    const n = composeDigestNotification([
      {
        childId: 'c1',
        childName: 'Alya',
        streakText: 'streak A',
        kabarCount: 1,
        hasUsageData: true,
      },
      {
        childId: 'c2',
        childName: 'Budi',
        streakText: 'streak B',
        kabarCount: 2,
        hasUsageData: true,
      },
    ]);
    assert.equal(n.title, 'Ringkasan minggu ini · 2 anak');
    assert.match(n.body, /Alya/);
    assert.match(n.body, /Budi/);
    assert.equal(n.primaryChildId, 'c1');
  });
});

describe('jakartaDigestWeekStart', () => {
  it('returns the Sunday of the current Jakarta week', () => {
    // 2026-08-02 is a Sunday in Jakarta
    const sunday = new Date('2026-08-02T12:00:00+07:00');
    assert.equal(jakartaDigestWeekStart(sunday), '2026-08-02');
    // Wednesday of that week
    const wed = new Date('2026-08-05T12:00:00+07:00');
    assert.equal(jakartaDigestWeekStart(wed), '2026-08-02');
  });
});

describe('isDigestSendWindow', () => {
  it('is true only on Sunday at the configured hour', () => {
    const sundayEvening = new Date('2026-08-02T19:30:00+07:00');
    assert.equal(jakartaHour(sundayEvening), 19);
    assert.equal(isDigestSendWindow(sundayEvening), true);
    const sundayNoon = new Date('2026-08-02T12:00:00+07:00');
    assert.equal(isDigestSendWindow(sundayNoon), false);
    const mondayEvening = new Date('2026-08-03T19:30:00+07:00');
    assert.equal(isDigestSendWindow(mondayEvening), false);
  });
});
