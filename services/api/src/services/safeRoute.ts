import { pool } from '../db/pool.js';
import { config } from '../config.js';
import { haversineM, type LatLng } from './tripLogic.js';

function pointNearSegment(p: LatLng, a: LatLng, b: LatLng, thresholdM: number): boolean {
  const samples = [a, b, { lat: (a.lat + b.lat) / 2, lng: (a.lng + b.lng) / 2 }];
  return samples.some((s) => haversineM(p, s) <= thresholdM);
}

function decodePolyline(encoded: string): LatLng[] {
  let index = 0;
  let lat = 0;
  let lng = 0;
  const coordinates: LatLng[] = [];

  while (index < encoded.length) {
    let result = 0;
    let shift = 0;
    let b: number;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = result & 1 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = result & 1 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    coordinates.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return coordinates;
}

async function activeReportPins(): Promise<Array<LatLng & { id: string; category: string }>> {
  await pool.query(
    `UPDATE community_reports
     SET status = 'expired'
     WHERE status = 'active' AND expires_at < now()`,
  );

  const result = await pool.query<{
    id: string;
    category: string;
    lat: number;
    lng: number;
  }>(
    `SELECT id, category,
            ST_Y(location::geometry) AS lat,
            ST_X(location::geometry) AS lng
     FROM community_reports
     WHERE status IN ('active', 'verified')
       AND (status = 'verified' OR expires_at > now())`,
  );
  return result.rows.map((r) => ({
    id: r.id,
    category: r.category,
    lat: Number(r.lat),
    lng: Number(r.lng),
  }));
}

function routeAvoidsReports(
  path: LatLng[],
  reports: Array<LatLng & { id: string }>,
  avoidRadiusM: number,
): { ok: boolean; nearReportIds: string[] } {
  const nearReportIds = new Set<string>();
  for (const report of reports) {
    for (let i = 0; i < path.length - 1; i += 1) {
      if (pointNearSegment(report, path[i], path[i + 1], avoidRadiusM)) {
        nearReportIds.add(report.id);
        break;
      }
    }
  }
  return { ok: nearReportIds.size === 0, nearReportIds: [...nearReportIds] };
}

export type SafeRouteResult = {
  provider: 'google_directions' | 'straight_line_fallback';
  mode: 'walking' | 'driving';
  distanceM: number | null;
  durationSec: number | null;
  polyline: string | null;
  path: LatLng[];
  avoidsReports: boolean;
  nearReportIds: string[];
  detourApplied: boolean;
  reportsConsidered: number;
  note: string;
};

export async function computeSafeRoute(params: {
  originLat: number;
  originLng: number;
  destLat: number;
  destLng: number;
  mode?: 'walking' | 'driving';
}): Promise<SafeRouteResult> {
  const mode = params.mode ?? 'walking';
  const reports = await activeReportPins();
  const avoidRadiusM = config.ROUTE_AVOID_RADIUS_M;
  let path: LatLng[] = [
    { lat: params.originLat, lng: params.originLng },
    { lat: params.destLat, lng: params.destLng },
  ];
  let provider: 'google_directions' | 'straight_line_fallback' = 'straight_line_fallback';
  let distanceM: number | null = Math.round(haversineM(path[0], path[path.length - 1]));
  let durationSec: number | null = null;
  let polyline: string | null = null;

  if (config.GOOGLE_MAPS_API_KEY) {
    const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
    url.searchParams.set('origin', `${params.originLat},${params.originLng}`);
    url.searchParams.set('destination', `${params.destLat},${params.destLng}`);
    url.searchParams.set('mode', mode);
    url.searchParams.set('key', config.GOOGLE_MAPS_API_KEY);

    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(8_000) });
      const data = (await response.json()) as {
        status: string;
        routes?: Array<{
          overview_polyline?: { points?: string };
          legs?: Array<{ distance?: { value: number }; duration?: { value: number } }>;
        }>;
      };

      if (data.status === 'OK' && data.routes?.[0]) {
        const route = data.routes[0];
        polyline = route.overview_polyline?.points ?? null;
        if (polyline) {
          path = decodePolyline(polyline);
        }
        const leg = route.legs?.[0];
        distanceM = leg?.distance?.value ?? distanceM;
        durationSec = leg?.duration?.value ?? null;
        provider = 'google_directions';
      }
    } catch (error) {
      console.error('google_directions_failed', error);
    }
  }

  const avoidance = routeAvoidsReports(path, reports, avoidRadiusM);
  let detourApplied = false;
  if (!avoidance.ok && path.length >= 2) {
    const mid = {
      lat: (params.originLat + params.destLat) / 2 + 0.002,
      lng: (params.originLng + params.destLng) / 2 - 0.002,
    };
    const detourPath = [
      { lat: params.originLat, lng: params.originLng },
      mid,
      { lat: params.destLat, lng: params.destLng },
    ];
    const detourCheck = routeAvoidsReports(detourPath, reports, avoidRadiusM);
    if (detourCheck.ok || detourCheck.nearReportIds.length < avoidance.nearReportIds.length) {
      path = detourPath;
      distanceM = Math.round(
        haversineM(detourPath[0], detourPath[1]) + haversineM(detourPath[1], detourPath[2]),
      );
      detourApplied = true;
      Object.assign(avoidance, detourCheck);
    }
  }

  return {
    provider,
    mode,
    distanceM,
    durationSec,
    polyline,
    path,
    avoidsReports: avoidance.ok,
    nearReportIds: avoidance.nearReportIds,
    detourApplied,
    reportsConsidered: reports.length,
    note: avoidance.ok
      ? 'Rute menghindari pin laporan aktif'
      : 'Rute masih dekat beberapa pin — pertimbangkan jalan alternatif',
  };
}
