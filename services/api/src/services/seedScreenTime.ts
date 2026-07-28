import type { Pool, PoolClient } from 'pg';

const APPS = [
  { packageName: 'com.google.android.youtube', appLabel: 'YouTube', weight: 0.38 },
  { packageName: 'com.ss.android.ugc.trill', appLabel: 'TikTok', weight: 0.28 },
  { packageName: 'com.whatsapp', appLabel: 'WhatsApp', weight: 0.14 },
  { packageName: 'com.instagram.android', appLabel: 'Instagram', weight: 0.12 },
  { packageName: 'com.android.chrome', appLabel: 'Chrome', weight: 0.08 },
] as const;

/** Multipliers vs daily limit (120 min default). Tue/Fri high for weekday pattern. */
const DOW_MULT: Record<number, number> = {
  0: 0.38, // Sun
  1: 0.72, // Mon
  2: 1.38, // Tue
  3: 0.78, // Wed
  4: 0.82, // Thu
  5: 1.42, // Fri
  6: 0.42, // Sat
};

export type SeedScreenTimeOptions = {
  childIds: string[];
  /** Number of Jakarta calendar days including today. Clamped 14–42. */
  days?: number;
  /** Daily limit used to shape totals (minutes). Default 120. */
  limitMinutes?: number;
  /** Deterministic salt so Andi/Zahira differ slightly. */
  profileSalt?: number;
};

export type SeedScreenTimeResult = {
  childId: string;
  days: number;
  usageEvents: number;
  hourlyEvents: number;
  insightsCleared: number;
};

function jakartaParts(date: Date): { y: number; m: number; d: number; dow: number } {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    weekday: 'short',
  });
  const parts = Object.fromEntries(fmt.formatToParts(date).map((p) => [p.type, p.value]));
  const dowMap: Record<string, number> = {
    Sun: 0,
    Mon: 1,
    Tue: 2,
    Wed: 3,
    Thu: 4,
    Fri: 5,
    Sat: 6,
  };
  return {
    y: Number(parts.year),
    m: Number(parts.month),
    d: Number(parts.day),
    dow: dowMap[parts.weekday ?? 'Mon'] ?? 1,
  };
}

function jakartaDayString(date: Date): string {
  const { y, m, d } = jakartaParts(date);
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** Noon Jakarta on calendar day offset from today (0 = today). */
function jakartaNoonUtc(daysAgo: number): Date {
  const now = new Date();
  const { y, m, d } = jakartaParts(now);
  // Build as UTC then shift: Jakarta is UTC+7, noon local = 05:00Z
  const utc = Date.UTC(y, m - 1, d - daysAgo, 5, 0, 0);
  return new Date(utc);
}

function hashSalt(childId: string): number {
  let h = 0;
  for (let i = 0; i < childId.length; i++) h = (h * 31 + childId.charCodeAt(i)) >>> 0;
  return h % 97;
}

function dayTotalSeconds(
  daysAgo: number,
  dow: number,
  limitMinutes: number,
  salt: number,
): number {
  const base = limitMinutes * 60;
  let mult = DOW_MULT[dow] ?? 0.75;
  // Mild per-child / per-day wobble (±8%)
  const wobble = 1 + (((salt + daysAgo * 7) % 17) - 8) / 100;
  mult *= wobble;
  // One over-limit spike mid-window for heatmap danger cells
  if (daysAgo === 3 || daysAgo === 10) mult = Math.max(mult, 1.25);
  // Keep several recent days under limit for streak copy
  if (daysAgo <= 6 && ![2, 5].includes(daysAgo)) {
    mult = Math.min(mult, 0.85);
  }
  // Force Tue/Fri high even in the recent week (weekday pattern needs ≥3 weeks)
  if (dow === 2 || dow === 5) {
    mult = Math.max(mult, 1.35);
  }
  return Math.max(600, Math.round(base * mult));
}

function splitAcrossApps(totalSeconds: number, salt: number) {
  const skew = ((salt % 5) - 2) * 0.01;
  const weights = APPS.map((a, i) => ({
    ...a,
    w: Math.max(0.05, a.weight + (i === 0 ? skew : i === 1 ? -skew : 0)),
  }));
  const sumW = weights.reduce((s, a) => s + a.w, 0);
  let remaining = totalSeconds;
  return weights.map((a, idx) => {
    const secs =
      idx === weights.length - 1
        ? remaining
        : Math.max(60, Math.round((totalSeconds * a.w) / sumW));
    remaining -= secs;
    return {
      packageName: a.packageName,
      appLabel: a.appLabel,
      durationSeconds: Math.max(30, secs),
    };
  });
}

async function upsertUsage(
  client: Pool | PoolClient,
  row: {
    childId: string;
    clientEventId: string;
    kind: 'usage' | 'usage_hourly';
    packageName: string;
    durationSeconds: number;
    recordedAt: Date;
    payload: Record<string, unknown>;
  },
): Promise<void> {
  await client.query(
    `INSERT INTO usage_telemetry
       (child_id, device_id, client_event_id, kind, package_name,
        duration_seconds, recorded_at, payload)
     VALUES ($1, NULL, $2, $3, $4, $5, $6, $7::jsonb)
     ON CONFLICT (child_id, client_event_id) DO UPDATE
       SET duration_seconds = EXCLUDED.duration_seconds,
           recorded_at = EXCLUDED.recorded_at,
           payload = EXCLUDED.payload,
           kind = EXCLUDED.kind,
           package_name = EXCLUDED.package_name`,
    [
      row.childId,
      row.clientEventId,
      row.kind,
      row.packageName,
      row.durationSeconds,
      row.recordedAt.toISOString(),
      JSON.stringify(row.payload),
    ],
  );
}

/**
 * Insert ~N days of daily `usage` + last-7-day `usage_hourly` for heatmap + insights.
 * Clears today's `screentime_insights` cache so the next GET rebuilds.
 */
export async function seedScreenTimeForChildren(
  db: Pool | PoolClient,
  options: SeedScreenTimeOptions,
): Promise<SeedScreenTimeResult[]> {
  const days = Math.min(42, Math.max(14, options.days ?? 35));
  const limitMinutes = options.limitMinutes ?? 120;
  const results: SeedScreenTimeResult[] = [];

  for (const childId of options.childIds) {
    const salt = (options.profileSalt ?? 0) + hashSalt(childId);
    let usageEvents = 0;
    let hourlyEvents = 0;

    // Replace the window so real device uploads do not stack on demo rows
    // and flatten Tue/Fri / under-limit patterns.
    const windowStart = jakartaNoonUtc(days - 1);
    windowStart.setUTCHours(windowStart.getUTCHours() - 12);
    await db.query(
      `DELETE FROM usage_telemetry
       WHERE child_id = $1
         AND kind IN ('usage', 'usage_hourly')
         AND recorded_at >= $2`,
      [childId, windowStart.toISOString()],
    );

    for (let daysAgo = 0; daysAgo < days; daysAgo++) {
      const recordedAt = jakartaNoonUtc(daysAgo);
      const day = jakartaDayString(recordedAt);
      const dow = jakartaParts(recordedAt).dow;
      const total = dayTotalSeconds(daysAgo, dow, limitMinutes, salt);
      const apps = splitAcrossApps(total, salt + daysAgo);

      for (const app of apps) {
        await upsertUsage(db, {
          childId,
          clientEventId: `seed-demo-usage-${day}-${app.packageName}`,
          kind: 'usage',
          packageName: app.packageName,
          durationSeconds: app.durationSeconds,
          recordedAt,
          payload: { appLabel: app.appLabel, seed: true },
        });
        usageEvents += 1;
      }
    }

    // Peak window: YouTube / TikTok evenings for the last 7 Jakarta days.
    for (let daysAgo = 0; daysAgo < 7; daysAgo++) {
      const dayDate = jakartaNoonUtc(daysAgo);
      const day = jakartaDayString(dayDate);
      const peakApps = [
        { packageName: APPS[0].packageName, appLabel: APPS[0].appLabel, hours: [20, 21, 22] },
        { packageName: APPS[1].packageName, appLabel: APPS[1].appLabel, hours: [21, 22] },
      ];
      for (const peak of peakApps) {
        for (const hour of peak.hours) {
          const secs = 900 + ((salt + daysAgo + hour) % 5) * 120;
          // recorded_at must be within last 7 days for insights loader;
          // keep wall-clock recent while payload.day/hour carry the bucket.
          const recordedAt = new Date(Date.now() - daysAgo * 3_600_000 - hour * 1_000);
          await upsertUsage(db, {
            childId,
            clientEventId: `seed-demo-hourly-${day}-${hour}-${peak.packageName}`,
            kind: 'usage_hourly',
            packageName: peak.packageName,
            durationSeconds: secs,
            recordedAt,
            payload: {
              appLabel: peak.appLabel,
              hour,
              day,
              seed: true,
            },
          });
          hourlyEvents += 1;
        }
      }
    }

    const cleared = await db.query(
      `DELETE FROM screentime_insights
       WHERE child_id = $1
         AND date = (now() AT TIME ZONE 'Asia/Jakarta')::date`,
      [childId],
    );

    results.push({
      childId,
      days,
      usageEvents,
      hourlyEvents,
      insightsCleared: cleared.rowCount ?? 0,
    });
  }

  return results;
}

export async function listChildrenForParent(
  db: Pool | PoolClient,
  parentId: string,
): Promise<Array<{ id: string; name: string | null }>> {
  const result = await db.query<{ id: string; name: string | null }>(
    `SELECT u.id, u.name
     FROM parent_children pc
     JOIN users u ON u.id = pc.child_id
     WHERE pc.parent_id = $1
     ORDER BY u.name NULLS LAST, u.created_at`,
    [parentId],
  );
  return result.rows;
}
