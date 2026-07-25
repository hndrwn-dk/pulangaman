export type HomeByMode = 'off' | 'maghrib' | 'custom';
export type WeekendMode = 'off' | 'same' | 'custom';
export type HomeByStatus =
  | 'pending'
  | 'pre_notified'
  | 'target_notified'
  | 'grace_notified'
  | 'resolved'
  | 'skipped';

export type ChildAckReason =
  | 'in_transit'
  | 'stopped_by'
  | 'school_activity'
  | 'other';

export type ClockTime = { hour: number; minute: number };

/** Asia/Jakarta calendar date YYYY-MM-DD for a UTC/instant. */
export function jakartaDateString(at: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/** Day of week in Asia/Jakarta: 0=Sun … 6=Sat (JS getDay style). */
export function jakartaWeekday(at: Date = new Date()): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Jakarta',
    weekday: 'short',
  }).formatToParts(at);
  const wd = parts.find((p) => p.type === 'weekday')?.value ?? 'Mon';
  const map: Record<string, number> = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };
  return map[wd] ?? 1;
}

export function isWeekendJakarta(at: Date = new Date()): boolean {
  const d = jakartaWeekday(at);
  return d === 0 || d === 6;
}

export function isSkippedDay(params: {
  eventDate: string;
  skipDates: Iterable<string>;
}): boolean {
  return new Set(params.skipDates).has(params.eventDate);
}

/**
 * Decide whether today's check should be skipped before any stage logic.
 * Returns a reason string when skipped, otherwise null.
 */
export function daySkipReason(params: {
  eventDate: string;
  skipDates: Iterable<string>;
  weekendMode: WeekendMode;
  at?: Date;
}): 'skip_date' | 'weekend_off' | null {
  if (isSkippedDay({ eventDate: params.eventDate, skipDates: params.skipDates })) {
    return 'skip_date';
  }
  if (isWeekendJakarta(params.at ?? new Date()) && params.weekendMode === 'off') {
    return 'weekend_off';
  }
  return null;
}

export function resolveActiveClock(params: {
  mode: HomeByMode;
  customHour: number | null;
  customMinute: number | null;
  weekendMode: WeekendMode;
  weekendHour: number | null;
  weekendMinute: number | null;
  maghrib: ClockTime | null;
  at?: Date;
}): { kind: 'off' | 'clock'; clock?: ClockTime; source?: string } {
  if (params.mode === 'off') {
    return { kind: 'off' };
  }

  const weekend = isWeekendJakarta(params.at ?? new Date());
  if (weekend && params.weekendMode === 'off') {
    return { kind: 'off' };
  }

  if (weekend && params.weekendMode === 'custom') {
    if (params.weekendHour == null || params.weekendMinute == null) {
      return { kind: 'off' };
    }
    return {
      kind: 'clock',
      clock: { hour: params.weekendHour, minute: params.weekendMinute },
      source: 'weekend_custom',
    };
  }

  // weekday, or weekend with weekendMode === 'same'
  if (params.mode === 'custom') {
    if (params.customHour == null || params.customMinute == null) {
      return { kind: 'off' };
    }
    return {
      kind: 'clock',
      clock: { hour: params.customHour, minute: params.customMinute },
      source: 'custom',
    };
  }

  // maghrib
  if (!params.maghrib) {
    return { kind: 'off' };
  }
  return {
    kind: 'clock',
    clock: params.maghrib,
    source: 'maghrib',
  };
}

/** Build a Date for HH:mm on the given Jakarta calendar date. */
export function jakartaLocalDateTime(
  eventDate: string,
  clock: ClockTime,
): Date {
  const hh = String(clock.hour).padStart(2, '0');
  const mm = String(clock.minute).padStart(2, '0');
  // Asia/Jakarta is UTC+7 year-round (no DST).
  return new Date(`${eventDate}T${hh}:${mm}:00+07:00`);
}

export function shouldPreNotify(params: {
  now: Date;
  targetTime: Date;
  preNotifiedAt: Date | null;
  status: HomeByStatus;
}): boolean {
  if (params.status === 'resolved' || params.status === 'skipped') return false;
  if (params.preNotifiedAt) return false;
  const preAt = new Date(params.targetTime.getTime() - 30 * 60_000);
  return params.now.getTime() >= preAt.getTime();
}

export function shouldNotifyTarget(params: {
  now: Date;
  effectiveDeadline: Date;
  targetNotifiedAt: Date | null;
  status: HomeByStatus;
}): boolean {
  if (params.status === 'resolved' || params.status === 'skipped') return false;
  if (params.targetNotifiedAt) return false;
  return params.now.getTime() >= params.effectiveDeadline.getTime();
}

export function shouldEscalate(params: {
  now: Date;
  effectiveDeadline: Date;
  gracePeriodMinutes: number;
  graceNotifiedAt: Date | null;
  status: HomeByStatus;
}): boolean {
  if (params.status === 'resolved' || params.status === 'skipped') return false;
  if (params.graceNotifiedAt) return false;
  const graceAt = new Date(
    params.effectiveDeadline.getTime() + params.gracePeriodMinutes * 60_000,
  );
  return params.now.getTime() >= graceAt.getTime();
}

export function isResolvedHome(params: {
  isHome: boolean;
  status: HomeByStatus;
}): boolean {
  if (params.status === 'resolved' || params.status === 'skipped') return false;
  return params.isHome;
}

export function canAcceptChildAck(params: {
  status: HomeByStatus;
  childAckAt: Date | null;
}): { ok: true } | { ok: false; error: string } {
  if (params.childAckAt) {
    return { ok: false, error: 'ack_already_used' };
  }
  if (params.status !== 'pre_notified' && params.status !== 'target_notified') {
    return { ok: false, error: 'ack_not_available' };
  }
  return { ok: true };
}

export function applyChildAck(params: {
  effectiveDeadline: Date;
  extensionMinutes: number;
  reason: ChildAckReason;
  note?: string | null;
  now?: Date;
}): {
  childAckAt: Date;
  childAckReason: ChildAckReason;
  childAckNote: string | null;
  effectiveDeadline: Date;
} {
  const now = params.now ?? new Date();
  const note =
    params.note == null || params.note.trim() === ''
      ? null
      : params.note.trim().slice(0, 140);
  return {
    childAckAt: now,
    childAckReason: params.reason,
    childAckNote: note,
    effectiveDeadline: new Date(
      params.effectiveDeadline.getTime() + params.extensionMinutes * 60_000,
    ),
  };
}

export function nextStatusAfterStage(
  stage: 'pre' | 'target' | 'grace' | 'resolved' | 'skipped',
): HomeByStatus {
  switch (stage) {
    case 'pre':
      return 'pre_notified';
    case 'target':
      return 'target_notified';
    case 'grace':
      return 'grace_notified';
    case 'resolved':
      return 'resolved';
    case 'skipped':
      return 'skipped';
  }
}

export function parentTargetCopy(params: {
  childName: string;
  targetLabel: string;
  childAckReason: ChildAckReason | null;
}): { title: string; body: string } {
  if (params.childAckReason) {
    const reasonText: Record<ChildAckReason, string> = {
      in_transit: 'masih di jalan',
      stopped_by: 'mampir dulu',
      school_activity: 'ada kegiatan sekolah',
      other: 'sedang dalam perjalanan pulang',
    };
    return {
      title: `Update dari ${params.childName}`,
      body: `${params.childName} bilang ${reasonText[params.childAckReason]}`,
    };
  }
  return {
    title: 'Belum di rumah',
    body: `${params.childName} belum sampai di rumah, jadwal pulang jam ${params.targetLabel}`,
  };
}

export function parentGraceCopy(params: {
  childName: string;
  elapsedLabel: string;
}): { title: string; body: string } {
  return {
    title: `${params.childName} masih belum di rumah`,
    body: `${params.childName} belum tiba setelah ${params.elapsedLabel}. Cek lokasi atau hubungi anak.`,
  };
}

export function childPreNotifyCopy(params: {
  childName: string;
}): { title: string; body: string } {
  return {
    title: 'Waktunya pulang',
    body: `${params.childName}, sebentar lagi waktu pulang ya`,
  };
}
