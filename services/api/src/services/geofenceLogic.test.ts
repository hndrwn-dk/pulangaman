import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { nextPresence, shouldEmitZoneEvent } from './geofenceLogic.js';

describe('nextPresence', () => {
  it('enters when inside radius from unknown', () => {
    assert.equal(
      nextPresence({ previous: 'unknown', distanceM: 40, radiusM: 50, hysteresisM: 15 }),
      'inside',
    );
  });

  it('stays inside within hysteresis band', () => {
    assert.equal(
      nextPresence({ previous: 'inside', distanceM: 55, radiusM: 50, hysteresisM: 15 }),
      'inside',
    );
  });

  it('exits only beyond radius + hysteresis', () => {
    assert.equal(
      nextPresence({ previous: 'inside', distanceM: 70, radiusM: 50, hysteresisM: 15 }),
      'outside',
    );
  });
});

describe('shouldEmitZoneEvent', () => {
  it('emits on transition after debounce', () => {
    assert.equal(
      shouldEmitZoneEvent({
        previous: 'outside',
        next: 'inside',
        sinceLastEventMs: 60_000,
        debounceMs: 45_000,
      }),
      true,
    );
  });

  it('suppresses chatter inside debounce window', () => {
    assert.equal(
      shouldEmitZoneEvent({
        previous: 'outside',
        next: 'inside',
        sinceLastEventMs: 10_000,
        debounceMs: 45_000,
      }),
      false,
    );
  });

  it('does not emit initial unknown seeding', () => {
    assert.equal(
      shouldEmitZoneEvent({
        previous: 'unknown',
        next: 'inside',
        sinceLastEventMs: 0,
        debounceMs: 45_000,
      }),
      false,
    );
  });
});
