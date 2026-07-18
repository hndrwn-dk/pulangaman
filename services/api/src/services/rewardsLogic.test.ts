import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { nextStreak } from './rewardsLogic.js';

describe('nextStreak', () => {
  it('starts streak from zero', () => {
    assert.equal(
      nextStreak({ lastAwardDate: null, currentStreak: 0, today: '2026-07-18' }),
      1,
    );
  });

  it('increments consecutive days', () => {
    assert.equal(
      nextStreak({
        lastAwardDate: '2026-07-17',
        currentStreak: 3,
        today: '2026-07-18',
      }),
      4,
    );
  });

  it('resets after a gap', () => {
    assert.equal(
      nextStreak({
        lastAwardDate: '2026-07-15',
        currentStreak: 5,
        today: '2026-07-18',
      }),
      1,
    );
  });
});
