export type LatLng = { lat: number; lng: number };

export function haversineM(a: LatLng, b: LatLng): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export function clamp01(n: number): number {
  if (Number.isNaN(n) || !Number.isFinite(n)) return 0;
  if (n < 0) return 0;
  if (n > 1) return 1;
  return n;
}

/** Straight-line progress: 0 at origin, 1 at destination. */
export function straightLineProgress(params: {
  origin: LatLng;
  dest: LatLng;
  current: LatLng;
}): number {
  const total = haversineM(params.origin, params.dest);
  if (total < 1) return 1;
  const remaining = haversineM(params.current, params.dest);
  return clamp01(1 - remaining / total);
}

/**
 * Along-path progress using nearest path vertex index.
 * Falls back to straight-line when path is empty/short.
 */
export function pathProgress(params: {
  path: LatLng[];
  origin: LatLng;
  dest: LatLng;
  current: LatLng;
}): number {
  const path = params.path;
  if (path.length < 2) {
    return straightLineProgress(params);
  }

  let bestIdx = 0;
  let bestDist = Number.POSITIVE_INFINITY;
  for (let i = 0; i < path.length; i += 1) {
    const d = haversineM(params.current, path[i]);
    if (d < bestDist) {
      bestDist = d;
      bestIdx = i;
    }
  }
  return clamp01(bestIdx / (path.length - 1));
}

export function computeTripProgress(params: {
  path: LatLng[] | null | undefined;
  origin: LatLng;
  dest: LatLng;
  current: LatLng;
}): number {
  if (params.path && params.path.length >= 2) {
    return pathProgress({
      path: params.path,
      origin: params.origin,
      dest: params.dest,
      current: params.current,
    });
  }
  return straightLineProgress(params);
}

export function hasArrived(params: {
  current: LatLng;
  dest: LatLng;
  radiusM: number;
  insideDestZone?: boolean;
}): boolean {
  if (params.insideDestZone) return true;
  return haversineM(params.current, params.dest) <= arrivalRadiusM(params.radiusM);
}

/** Floor for GPS jitter / large destinations — zone radius alone is often too tight. */
export function arrivalRadiusM(zoneRadiusM: number): number {
  if (!Number.isFinite(zoneRadiusM) || zoneRadiusM <= 0) return 150;
  return Math.max(zoneRadiusM, 150);
}
