import { getRedis } from '../redis/client.js';
import { config } from '../config.js';
import { jakartaDateString } from './homeByLogic.js';
import type { ClockTime } from './homeByLogic.js';

function roundCoord(n: number): string {
  return n.toFixed(2);
}

function cacheKey(lat: number, lng: number, date: string): string {
  return `maghrib:${roundCoord(lat)}:${roundCoord(lng)}:${date}`;
}

function parseHhMm(raw: string): ClockTime | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(raw.trim());
  if (!m) return null;
  const hour = Number(m[1]);
  const minute = Number(m[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

function previousJakartaDate(date: string): string {
  const noon = new Date(`${date}T12:00:00+07:00`);
  return jakartaDateString(new Date(noon.getTime() - 86_400_000));
}

async function fetchAladhan(
  lat: number,
  lng: number,
  date: string,
): Promise<ClockTime | null> {
  const [y, mo, d] = date.split('-');
  if (!y || !mo || !d) return null;
  const pathDate = `${d}-${mo}-${y}`;
  const url =
    `https://api.aladhan.com/v1/timings/${pathDate}` +
    `?latitude=${lat}&longitude=${lng}&method=20`;
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8_000) });
    if (!res.ok) return null;
    const json = (await res.json()) as {
      data?: { timings?: { Maghrib?: string } };
    };
    const maghrib = json.data?.timings?.Maghrib;
    if (!maghrib) return null;
    return parseHhMm(maghrib.split(' ')[0] ?? '');
  } catch {
    return null;
  }
}

export async function getMaghribTime(
  lat: number,
  lng: number,
  date: string,
): Promise<{ hour: number; minute: number; source: 'api' | 'cache' | 'fallback' }> {
  const redis = getRedis();
  const key = cacheKey(lat, lng, date);

  try {
    const cached = await redis.get(key);
    if (cached) {
      const parsed = parseHhMm(cached);
      if (parsed) return { ...parsed, source: 'cache' };
    }
  } catch {
    // ignore redis errors
  }

  const fromApi = await fetchAladhan(lat, lng, date);
  if (fromApi) {
    try {
      await redis.set(
        key,
        `${fromApi.hour}:${String(fromApi.minute).padStart(2, '0')}`,
        'EX',
        25 * 3600,
      );
    } catch {
      // ignore
    }
    return { ...fromApi, source: 'api' };
  }

  try {
    const prevKey = cacheKey(lat, lng, previousJakartaDate(date));
    const cachedPrev = await redis.get(prevKey);
    if (cachedPrev) {
      const parsed = parseHhMm(cachedPrev);
      if (parsed) {
        console.warn('maghrib_fallback_prev_cache', { lat, lng, date });
        return { ...parsed, source: 'cache' };
      }
    }
  } catch {
    // ignore
  }

  console.warn('maghrib_fallback_static', {
    lat,
    lng,
    date,
    hour: config.MAGHRIB_FALLBACK_HOUR,
    minute: config.MAGHRIB_FALLBACK_MINUTE,
  });
  return {
    hour: config.MAGHRIB_FALLBACK_HOUR,
    minute: config.MAGHRIB_FALLBACK_MINUTE,
    source: 'fallback',
  };
}
