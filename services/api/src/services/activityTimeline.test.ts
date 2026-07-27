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

  it('synthesizes a trip when GPS jumps zone-to-zone with no trail', () => {
    const mall: ActivityZone = {
      id: 'z-mall',
      type: 'custom',
      name: 'Parkway Parade',
      lat: -6.25,
      lng: 106.85,
      radiusM: 150,
    };
    const t0 = new Date('2026-07-26T10:00:00.000Z');
    const points: ActivityPoint[] = [];
    for (let i = 0; i < 6; i++) {
      points.push({
        lat: home.lat,
        lng: home.lng,
        recordedAt: new Date(t0.getTime() + i * 60_000),
        accuracyM: 20,
      });
    }
    // Gap with no samples (tracking paused / stale last-known), then mall.
    const mallStart = t0.getTime() + 45 * 60_000;
    for (let i = 0; i < 6; i++) {
      points.push({
        lat: mall.lat,
        lng: mall.lng,
        recordedAt: new Date(mallStart + i * 60_000),
        accuracyM: 25,
      });
    }

    const { summary, events } = buildActivityTimeline({
      points,
      zones: [home, mall],
    });

    const trips = events.filter((e) => e.type === 'trip');
    assert.equal(trips.length, 1);
    const trip = trips[0]!;
    assert.equal(trip.type, 'trip');
    if (trip.type === 'trip') {
      assert.equal(trip.startLabel, 'Rumah');
      assert.equal(trip.endLabel, 'Parkway Parade');
      assert.ok(trip.distanceM > 1000);
      assert.equal(trip.inaccurate, true);
    }
    assert.ok(summary.totalDistanceM > 1000);
    assert.equal(summary.placeCount, 2);
  });

  it('keeps a short sparse trail that bridges two zones', () => {
    const t0 = new Date('2026-07-26T02:00:00.000Z');
    const points: ActivityPoint[] = [
      {
        lat: home.lat,
        lng: home.lng,
        recordedAt: new Date(t0.getTime()),
        accuracyM: 15,
      },
      {
        lat: home.lat,
        lng: home.lng,
        recordedAt: new Date(t0.getTime() + 5 * 60_000),
        accuracyM: 15,
      },
      // Single midpoint, <90s trip — old logic dropped these entirely.
      {
        lat: -6.205,
        lng: 106.81,
        recordedAt: new Date(t0.getTime() + 5 * 60_000 + 40_000),
        accuracyM: 40,
      },
      {
        lat: school.lat,
        lng: school.lng,
        recordedAt: new Date(t0.getTime() + 5 * 60_000 + 70_000),
        accuracyM: 20,
      },
      {
        lat: school.lat,
        lng: school.lng,
        recordedAt: new Date(t0.getTime() + 20 * 60_000),
        accuracyM: 20,
      },
    ];

    const { summary, events } = buildActivityTimeline({
      points,
      zones: [home, school],
    });

    assert.ok(events.some((e) => e.type === 'trip'));
    assert.ok(summary.totalDistanceM > 0);
  });

  it('jakartaDayBounds accepts YYYY-MM-DD', () => {
    const { start, end } = jakartaDayBounds('2026-07-20');
    assert.ok(end.getTime() > start.getTime());
  });
});
