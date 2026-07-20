export type ActivityPoint = {
  lat: number;
  lng: number;
  recordedAt: Date;
  accuracyM: number | null;
};

export type ActivityZone = {
  id: string;
  type: string;
  name: string | null;
  lat: number;
  lng: number;
  radiusM: number;
};

export type StayEvent = {
  type: 'stay';
  placeName: string;
  placeType: string;
  zoneId: string | null;
  startAt: string;
  endAt: string;
  durationSeconds: number;
};

export type TripEvent = {
  type: 'trip';
  startAt: string;
  endAt: string;
  durationSeconds: number;
  startLabel: string;
  endLabel: string;
  distanceM: number;
  inaccurate: boolean;
  path: Array<{ lat: number; lng: number }>;
};

export type ActivityEvent = StayEvent | TripEvent;

export type ActivitySummary = {
  placeCount: number;
  places: Array<{ name: string; placeType: string; durationSeconds: number }>;
  totalDistanceM: number;
};

const EARTH_R = 6371000;
const MIN_STAY_SECONDS = 4 * 60;
const MIN_TRIP_SECONDS = 90;
const MAX_PATH_POINTS = 48;

export function haversineM(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_R * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function zoneLabel(zone: ActivityZone): string {
  if (zone.name && zone.name.trim()) return zone.name.trim();
  if (zone.type === 'home') return 'Rumah';
  if (zone.type === 'school') return 'Sekolah';
  return 'Tempat aman';
}

export function matchZone(
  point: { lat: number; lng: number },
  zones: ActivityZone[],
): ActivityZone | null {
  let best: ActivityZone | null = null;
  let bestDist = Number.POSITIVE_INFINITY;
  for (const z of zones) {
    const d = haversineM(point, { lat: z.lat, lng: z.lng });
    if (d <= z.radiusM && d < bestDist) {
      best = z;
      bestDist = d;
    }
  }
  return best;
}

function simplifyPath(
  points: Array<{ lat: number; lng: number }>,
): Array<{ lat: number; lng: number }> {
  if (points.length <= MAX_PATH_POINTS) return points;
  const out: Array<{ lat: number; lng: number }> = [];
  const step = (points.length - 1) / (MAX_PATH_POINTS - 1);
  for (let i = 0; i < MAX_PATH_POINTS; i++) {
    const idx = Math.round(i * step);
    out.push(points[idx]!);
  }
  return out;
}

function pathDistanceM(points: Array<{ lat: number; lng: number }>): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    total += haversineM(points[i - 1]!, points[i]!);
  }
  return Math.round(total);
}

/**
 * Collapse GPS history into stay (in named zones) and trip segments.
 */
export function buildActivityTimeline(params: {
  points: ActivityPoint[];
  zones: ActivityZone[];
}): { summary: ActivitySummary; events: ActivityEvent[] } {
  const { points, zones } = params;
  if (points.length === 0) {
    return {
      summary: { placeCount: 0, places: [], totalDistanceM: 0 },
      events: [],
    };
  }

  type Seg =
    | {
        kind: 'stay';
        zone: ActivityZone;
        start: Date;
        end: Date;
        points: ActivityPoint[];
      }
    | {
        kind: 'trip';
        start: Date;
        end: Date;
        points: ActivityPoint[];
      };

  const raw: Seg[] = [];
  let current: Seg | null = null;

  for (const p of points) {
    const zone = matchZone(p, zones);
    if (zone) {
      if (current?.kind === 'stay' && current.zone.id === zone.id) {
        current.end = p.recordedAt;
        current.points.push(p);
      } else {
        if (current) raw.push(current);
        current = {
          kind: 'stay',
          zone,
          start: p.recordedAt,
          end: p.recordedAt,
          points: [p],
        };
      }
    } else if (current?.kind === 'trip') {
      current.end = p.recordedAt;
      current.points.push(p);
    } else {
      if (current) raw.push(current);
      current = {
        kind: 'trip',
        start: p.recordedAt,
        end: p.recordedAt,
        points: [p],
      };
    }
  }
  if (current) raw.push(current);

  // Drop micro-stays into neighboring trips / merge short stays.
  const merged: Seg[] = [];
  for (const seg of raw) {
    if (seg.kind === 'stay') {
      const dur = (seg.end.getTime() - seg.start.getTime()) / 1000;
      if (dur < MIN_STAY_SECONDS && merged.length > 0) {
        const prev = merged[merged.length - 1]!;
        if (prev.kind === 'trip') {
          prev.end = seg.end;
          prev.points.push(...seg.points);
          continue;
        }
      }
      if (dur < MIN_STAY_SECONDS) {
        merged.push({
          kind: 'trip',
          start: seg.start,
          end: seg.end,
          points: seg.points,
        });
        continue;
      }
    }
    if (seg.kind === 'trip' && merged.length > 0) {
      const prev = merged[merged.length - 1]!;
      if (prev.kind === 'trip') {
        prev.end = seg.end;
        prev.points.push(...seg.points);
        continue;
      }
    }
    merged.push(seg);
  }

  const events: ActivityEvent[] = [];
  const placeDur = new Map<string, { name: string; placeType: string; durationSeconds: number }>();
  let totalDistanceM = 0;

  for (let i = 0; i < merged.length; i++) {
    const seg = merged[i]!;
    const durationSeconds = Math.max(
      0,
      Math.round((seg.end.getTime() - seg.start.getTime()) / 1000),
    );

    if (seg.kind === 'stay') {
      const name = zoneLabel(seg.zone);
      const key = `${seg.zone.id}:${name}`;
      const prev = placeDur.get(key);
      placeDur.set(key, {
        name,
        placeType: seg.zone.type,
        durationSeconds: (prev?.durationSeconds ?? 0) + durationSeconds,
      });
      events.push({
        type: 'stay',
        placeName: name,
        placeType: seg.zone.type,
        zoneId: seg.zone.id,
        startAt: seg.start.toISOString(),
        endAt: seg.end.toISOString(),
        durationSeconds,
      });
      continue;
    }

    if (durationSeconds < MIN_TRIP_SECONDS && seg.points.length < 3) {
      continue;
    }

    const pathPts = seg.points.map((p) => ({ lat: p.lat, lng: p.lng }));
    const distanceM = pathDistanceM(pathPts);
    totalDistanceM += distanceM;

    const prevStay = [...merged.slice(0, i)].reverse().find((s) => s.kind === 'stay');
    const nextStay = merged.slice(i + 1).find((s) => s.kind === 'stay');
    const startLabel =
      prevStay && prevStay.kind === 'stay' ? zoneLabel(prevStay.zone) : 'Berangkat';
    const endLabel =
      nextStay && nextStay.kind === 'stay' ? zoneLabel(nextStay.zone) : 'Dalam perjalanan';

    const accuracies = seg.points
      .map((p) => p.accuracyM)
      .filter((a): a is number => typeof a === 'number');
    const avgAcc =
      accuracies.length > 0
        ? accuracies.reduce((s, n) => s + n, 0) / accuracies.length
        : 0;
    const spanMin = durationSeconds / 60;
    const sparse = spanMin > 10 && seg.points.length < 4;
    const inaccurate = avgAcc > 80 || sparse || distanceM > 80_000;

    events.push({
      type: 'trip',
      startAt: seg.start.toISOString(),
      endAt: seg.end.toISOString(),
      durationSeconds,
      startLabel,
      endLabel,
      distanceM,
      inaccurate,
      path: simplifyPath(pathPts),
    });
  }

  // Newest first for parent feed (FMK-style).
  events.reverse();

  return {
    summary: {
      placeCount: placeDur.size,
      places: [...placeDur.values()].sort((a, b) => b.durationSeconds - a.durationSeconds),
      totalDistanceM,
    },
    events,
  };
}

/** Calendar day YYYY-MM-DD in Asia/Jakarta. */
export function jakartaDayBounds(day: string): { start: Date; end: Date } {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    throw new Error('invalid_day');
  }
  return {
    start: new Date(`${day}T00:00:00+08:00`),
    end: new Date(`${day}T23:59:59.999+08:00`),
  };
}

export function todayJakartaDay(now = new Date()): string {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return fmt.format(now);
}
