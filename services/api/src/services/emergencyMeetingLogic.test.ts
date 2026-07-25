import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ARRIVAL_RADIUS_METERS,
  buildActivationTargets,
  formatDistanceLabel,
  haversineMeters,
  isArrivedAt,
  uniqueGuardianIds,
} from './emergencyMeetingLogic.js';

describe('isArrivedAt', () => {
  it('counts a child inside the radius as arrived', () => {
    assert.equal(isArrivedAt(0), true);
    assert.equal(isArrivedAt(ARRIVAL_RADIUS_METERS), true);
  });

  it('does not count unknown or far distances', () => {
    assert.equal(isArrivedAt(null), false);
    assert.equal(isArrivedAt(Number.NaN), false);
    assert.equal(isArrivedAt(ARRIVAL_RADIUS_METERS + 1), false);
  });
});

describe('buildActivationTargets', () => {
  it('marks children without a point as not notified', () => {
    const targets = buildActivationTargets([
      {
        childId: 'c1',
        childName: 'Andi',
        meetingPointId: 'p1',
        meetingPointName: 'Lapangan',
        guardianIds: ['g1'],
      },
      {
        childId: 'c2',
        childName: 'Zahira',
        meetingPointId: null,
        meetingPointName: null,
        guardianIds: ['g2'],
      },
    ]);
    assert.equal(targets[0].notified, true);
    assert.equal(targets[1].notified, false);
    assert.equal(targets[1].reason, 'no_point_configured');
    assert.deepEqual(targets[1].guardianIds, []);
  });
});

describe('uniqueGuardianIds', () => {
  it('dedupes guardians shared across children', () => {
    const targets = buildActivationTargets([
      {
        childId: 'c1',
        childName: 'A',
        meetingPointId: 'p1',
        meetingPointName: 'X',
        guardianIds: ['g1', 'g2'],
      },
      {
        childId: 'c2',
        childName: 'B',
        meetingPointId: 'p2',
        meetingPointName: 'Y',
        guardianIds: ['g2', 'g3'],
      },
    ]);
    const ids = uniqueGuardianIds(targets).sort();
    assert.deepEqual(ids, ['g1', 'g2', 'g3']);
  });

  it('skips guardians for children without a point', () => {
    const targets = buildActivationTargets([
      {
        childId: 'c1',
        childName: 'A',
        meetingPointId: null,
        meetingPointName: null,
        guardianIds: ['g1'],
      },
    ]);
    assert.deepEqual(uniqueGuardianIds(targets), []);
  });
});

describe('haversineMeters', () => {
  it('returns ~0 for same point', () => {
    const d = haversineMeters(
      { lat: -6.2, lng: 106.8 },
      { lat: -6.2, lng: 106.8 },
    );
    assert.ok(d < 1);
  });

  it('returns meters (not degrees) for nearby points', () => {
    // ~1.1 km north of origin at equator-ish latitude
    const d = haversineMeters(
      { lat: -6.2, lng: 106.8 },
      { lat: -6.21, lng: 106.8 },
    );
    assert.ok(d > 900 && d < 1300, `got ${d}`);
  });
});

describe('formatDistanceLabel', () => {
  it('formats km and m', () => {
    assert.equal(formatDistanceLabel(250), '250 m');
    assert.equal(formatDistanceLabel(2500), '2.5 km');
    assert.equal(formatDistanceLabel(null), '');
  });
});
