import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildActivityTimeline,
  haversineM,
  jakartaDayBounds,
  matchZone,
  type ActivityPoint,
  type ActivityZone,
} from './activityTimeline.js';

describe('activityTimeline', () => {
  const home: ActivityZone = {
    id: 'z-home',
    type: 'home',
    name: 'Rumah',
    lat: -6.2,
    lng: 106.8,
    radiusM: 120,
  };
  const school: ActivityZone = {
    id: 'z-school',
    type: 'school',
    name: 'Sekolah',
    lat: -6.21,
    lng: 106.82,
    radiusM: 100,
  };

  it('matchZone picks nearest matching zone', () => {
    const z = matchZone({ lat: -6.2001, lng: 106.8001 }, [home, school]);
    assert.equal(z?.id, 'z-home');
  });

  it('haversine is roughly correct for short distance', () => {
    const d = haversineM(
      { lat: -6.2, lng: 106.8 },
      { lat: -6.201, lng: 106.8 },
    );
    assert.ok(d > 100 && d < 130);
  });

  it('builds stay and trip events', () => {
    const t0 = new Date('2026-07-20T01:00:00.000Z');
    const points: ActivityPoint[] = [];
    // 20 min at home
    for (let i = 0; i < 10; i++) {
      points.push({
        lat: -6.2,
        lng: 106.8,
        recordedAt: new Date(t0.getTime() + i * 120_000),
        accuracyM: 20,
      });
    }
    // trip toward school (~15 min)
    const tripStart = t0.getTime() + 10 * 120_000;
    for (let i = 0; i < 8; i++) {
      const f = i / 7;
      points.push({
        lat: -6.2 + (-0.01) * f,
        lng: 106.8 + 0.02 * f,
        recordedAt: new Date(tripStart + i * 120_000),
        accuracyM: 25,
      });
    }
    // 15 min at school
    const schoolStart = tripStart + 8 * 120_000;
    for (let i = 0; i < 8; i++) {
      points.push({
        lat: -6.21,
        lng: 106.82,
        recordedAt: new Date(schoolStart + i * 120_000),
        accuracyM: 15,
      });
    }

    const { summary, events } = buildActivityTimeline({
      points,
      zones: [home, school],
    });

    assert.ok(summary.placeCount >= 2);
    assert.ok(events.some((e) => e.type === 'stay' && e.placeName === 'Rumah'));
    assert.ok(events.some((e) => e.type === 'stay' && e.placeName === 'Sekolah'));
    assert.ok(events.some((e) => e.type === 'trip'));
  });

  it('jakartaDayBounds accepts YYYY-MM-DD', () => {
    const { start, end } = jakartaDayBounds('2026-07-20');
    assert.ok(end.getTime() > start.getTime());
  });
});
