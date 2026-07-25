import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  clamp01,
  computeTripProgress,
  hasArrived,
  haversineM,
  pathProgress,
  straightLineProgress,
} from './tripLogic.js';

describe('clamp01', () => {
  it('clamps out of range', () => {
    assert.equal(clamp01(-0.5), 0);
    assert.equal(clamp01(1.5), 1);
    assert.equal(clamp01(0.4), 0.4);
  });
});

describe('straightLineProgress', () => {
  const origin = { lat: 1.3, lng: 103.8 };
  const dest = { lat: 1.31, lng: 103.81 };

  it('is ~0 at origin', () => {
    const p = straightLineProgress({ origin, dest, current: origin });
    assert.ok(p < 0.05);
  });

  it('is ~1 at destination', () => {
    const p = straightLineProgress({ origin, dest, current: dest });
    assert.ok(p > 0.95);
  });

  it('is mid-range halfway', () => {
    const mid = {
      lat: (origin.lat + dest.lat) / 2,
      lng: (origin.lng + dest.lng) / 2,
    };
    const p = straightLineProgress({ origin, dest, current: mid });
    assert.ok(p > 0.4 && p < 0.6);
  });
});

describe('pathProgress', () => {
  it('uses nearest vertex fraction', () => {
    const path = [
      { lat: 0, lng: 0 },
      { lat: 0.01, lng: 0 },
      { lat: 0.02, lng: 0 },
      { lat: 0.03, lng: 0 },
    ];
    const p = pathProgress({
      path,
      origin: path[0],
      dest: path[3],
      current: path[1],
    });
    assert.equal(p, 1 / 3);
  });

  it('falls back when path is short', () => {
    const origin = { lat: 0, lng: 0 };
    const dest = { lat: 0.02, lng: 0 };
    const p = pathProgress({
      path: [origin],
      origin,
      dest,
      current: dest,
    });
    assert.ok(p > 0.95);
  });
});

describe('computeTripProgress', () => {
  it('prefers path when available', () => {
    const path = [
      { lat: 0, lng: 0 },
      { lat: 0.01, lng: 0 },
      { lat: 0.02, lng: 0 },
    ];
    const p = computeTripProgress({
      path,
      origin: path[0],
      dest: path[2],
      current: path[1],
    });
    assert.equal(p, 0.5);
  });
});

describe('hasArrived', () => {
  const dest = { lat: 1.3, lng: 103.8 };

  it('arrives when inside dest zone flag', () => {
    assert.equal(
      hasArrived({
        current: { lat: 1.4, lng: 104 },
        dest,
        radiusM: 100,
        insideDestZone: true,
      }),
      true,
    );
  });

  it('arrives within radius', () => {
    const near = { lat: dest.lat + 0.0001, lng: dest.lng };
    assert.ok(haversineM(near, dest) < 50);
    assert.equal(
      hasArrived({ current: near, dest, radiusM: 100 }),
      true,
    );
  });

  it('not arrived when far', () => {
    assert.equal(
      hasArrived({
        current: { lat: 1.4, lng: 104 },
        dest,
        radiusM: 100,
      }),
      false,
    );
  });
});
