import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  applyChildAck,
  canAcceptChildAck,
  daySkipReason,
  isResolvedHome,
  jakartaDateString,
  jakartaLocalDateTime,
  parentTargetCopy,
  resolveActiveClock,
  shouldEscalate,
  shouldNotifyTarget,
  shouldPreNotify,
} from './homeByLogic.js';

describe('daySkipReason', () => {
  it('skips parent-marked holiday dates', () => {
    assert.equal(
      daySkipReason({
        eventDate: '2026-07-25',
        skipDates: ['2026-07-25'],
        weekendMode: 'same',
        at: new Date('2026-07-25T10:00:00+07:00'),
      }),
      'skip_date',
    );
  });

  it('skips Saturday when weekend_mode is off', () => {
    // 2026-07-25 is Saturday
    assert.equal(
      daySkipReason({
        eventDate: '2026-07-25',
        skipDates: [],
        weekendMode: 'off',
        at: new Date('2026-07-25T10:00:00+07:00'),
      }),
      'weekend_off',
    );
  });

  it('does not skip weekday', () => {
    // 2026-07-24 is Friday
    assert.equal(
      daySkipReason({
        eventDate: '2026-07-24',
        skipDates: [],
        weekendMode: 'off',
        at: new Date('2026-07-24T10:00:00+07:00'),
      }),
      null,
    );
  });
});

describe('resolveActiveClock', () => {
  it('returns off when mode is off', () => {
    assert.equal(
      resolveActiveClock({
        mode: 'off',
        customHour: 18,
        customMinute: 0,
        weekendMode: 'same',
        weekendHour: null,
        weekendMinute: null,
        maghrib: { hour: 17, minute: 55 },
      }).kind,
      'off',
    );
  });

  it('uses custom clock on weekday', () => {
    const r = resolveActiveClock({
      mode: 'custom',
      customHour: 18,
      customMinute: 30,
      weekendMode: 'off',
      weekendHour: null,
      weekendMinute: null,
      maghrib: null,
      at: new Date('2026-07-24T10:00:00+07:00'),
    });
    assert.equal(r.kind, 'clock');
    assert.deepEqual(r.clock, { hour: 18, minute: 30 });
  });

  it('uses maghrib clock when mode is maghrib', () => {
    const r = resolveActiveClock({
      mode: 'maghrib',
      customHour: null,
      customMinute: null,
      weekendMode: 'same',
      weekendHour: null,
      weekendMinute: null,
      maghrib: { hour: 17, minute: 48 },
      at: new Date('2026-07-24T10:00:00+07:00'),
    });
    assert.equal(r.kind, 'clock');
    assert.deepEqual(r.clock, { hour: 17, minute: 48 });
    assert.equal(r.source, 'maghrib');
  });

  it('uses weekend custom time on Saturday', () => {
    const r = resolveActiveClock({
      mode: 'custom',
      customHour: 18,
      customMinute: 0,
      weekendMode: 'custom',
      weekendHour: 20,
      weekendMinute: 0,
      maghrib: null,
      at: new Date('2026-07-25T10:00:00+07:00'),
    });
    assert.deepEqual(r.clock, { hour: 20, minute: 0 });
    assert.equal(r.source, 'weekend_custom');
  });
});

describe('stage gates', () => {
  const target = new Date('2026-07-24T18:00:00+07:00');

  it('pre-notifies at T-30 and only once', () => {
    assert.equal(
      shouldPreNotify({
        now: new Date('2026-07-24T17:30:00+07:00'),
        targetTime: target,
        preNotifiedAt: null,
        status: 'pending',
      }),
      true,
    );
    assert.equal(
      shouldPreNotify({
        now: new Date('2026-07-24T17:30:00+07:00'),
        targetTime: target,
        preNotifiedAt: new Date('2026-07-24T17:30:00+07:00'),
        status: 'pre_notified',
      }),
      false,
    );
  });

  it('target uses effective_deadline not raw target', () => {
    const deadline = new Date('2026-07-24T18:30:00+07:00');
    assert.equal(
      shouldNotifyTarget({
        now: new Date('2026-07-24T18:10:00+07:00'),
        effectiveDeadline: deadline,
        targetNotifiedAt: null,
        status: 'pre_notified',
      }),
      false,
    );
    assert.equal(
      shouldNotifyTarget({
        now: new Date('2026-07-24T18:30:00+07:00'),
        effectiveDeadline: deadline,
        targetNotifiedAt: null,
        status: 'pre_notified',
      }),
      true,
    );
  });

  it('grace fires even after ack (deadline already extended)', () => {
    const deadline = new Date('2026-07-24T18:30:00+07:00');
    assert.equal(
      shouldEscalate({
        now: new Date('2026-07-24T19:00:00+07:00'),
        effectiveDeadline: deadline,
        gracePeriodMinutes: 30,
        graceNotifiedAt: null,
        status: 'target_notified',
      }),
      true,
    );
  });

  it('home presence resolves and cancels remaining stages', () => {
    assert.equal(
      isResolvedHome({ isHome: true, status: 'pre_notified' }),
      true,
    );
    assert.equal(
      shouldNotifyTarget({
        now: new Date('2026-07-24T19:00:00+07:00'),
        effectiveDeadline: target,
        targetNotifiedAt: null,
        status: 'resolved',
      }),
      false,
    );
  });
});

describe('child ack', () => {
  it('allows one ack in pre_notified / target_notified only', () => {
    assert.equal(
      canAcceptChildAck({ status: 'pending', childAckAt: null }).ok,
      false,
    );
    assert.equal(
      canAcceptChildAck({ status: 'pre_notified', childAckAt: null }).ok,
      true,
    );
    assert.equal(
      canAcceptChildAck({
        status: 'pre_notified',
        childAckAt: new Date(),
      }).ok,
      false,
    );
  });

  it('extends effective_deadline and truncates note', () => {
    const base = new Date('2026-07-24T18:00:00+07:00');
    const applied = applyChildAck({
      effectiveDeadline: base,
      extensionMinutes: 30,
      reason: 'in_transit',
      note: 'x'.repeat(200),
      now: new Date('2026-07-24T17:40:00+07:00'),
    });
    assert.equal(applied.effectiveDeadline.toISOString(), new Date('2026-07-24T18:30:00+07:00').toISOString());
    assert.equal(applied.childAckNote?.length, 140);
  });

  it('swaps parent copy when ack present', () => {
    const withAck = parentTargetCopy({
      childName: 'Andi',
      targetLabel: '18:00',
      childAckReason: 'in_transit',
    });
    assert.match(withAck.title, /Update dari Andi/);
    assert.match(withAck.body, /di jalan/);

    const plain = parentTargetCopy({
      childName: 'Andi',
      targetLabel: '18:00',
      childAckReason: null,
    });
    assert.equal(plain.title, 'Belum di rumah');
  });
});

describe('jakarta day boundary', () => {
  it('keeps evening events on the Jakarta calendar date', () => {
    // 2026-07-24 22:00 WIB = 15:00 UTC same day
    const evening = new Date('2026-07-24T22:00:00+07:00');
    assert.equal(jakartaDateString(evening), '2026-07-24');

    const target = jakartaLocalDateTime('2026-07-24', { hour: 18, minute: 0 });
    assert.equal(target.toISOString(), new Date('2026-07-24T18:00:00+07:00').toISOString());
  });
});
