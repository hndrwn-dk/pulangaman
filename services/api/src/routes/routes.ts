import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { config } from '../config.js';

export const routesRouter = Router();

routesRouter.use(requireAuth, rateLimit);

type LatLng = { lat: number; lng: number };

function haversineM(a: LatLng, b: LatLng): number {
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

function pointNearSegment(p: LatLng, a: LatLng, b: LatLng, thresholdM: number): boolean {
  // Coarse check: first/last + midpoints.
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

routesRouter.post('/safe', async (req: AuthedRequest, res, next) => {
  try {
    if (!req.auth?.userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        originLat: z.number().min(-90).max(90),
        originLng: z.number().min(-180).max(180),
        destLat: z.number().min(-90).max(90),
        destLng: z.number().min(-180).max(180),
        mode: z.enum(['walking', 'driving']).default('walking'),
      })
      .parse(req.body);

    const reports = await activeReportPins();
    const avoidRadiusM = config.ROUTE_AVOID_RADIUS_M;
    let path: LatLng[] = [
      { lat: body.originLat, lng: body.originLng },
      { lat: body.destLat, lng: body.destLng },
    ];
    let provider: 'google_directions' | 'straight_line_fallback' = 'straight_line_fallback';
    let distanceM: number | null = Math.round(
      haversineM(path[0], path[path.length - 1]),
    );
    let durationSec: number | null = null;
    let polyline: string | null = null;

    if (config.GOOGLE_MAPS_API_KEY) {
      const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
      url.searchParams.set(
        'origin',
        `${body.originLat},${body.originLng}`,
      );
      url.searchParams.set(
        'destination',
        `${body.destLat},${body.destLng}`,
      );
      url.searchParams.set('mode', body.mode);
      url.searchParams.set('key', config.GOOGLE_MAPS_API_KEY);

      const response = await fetch(url);
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
    }

    const avoidance = routeAvoidsReports(path, reports, avoidRadiusM);

    // If primary path hits reports, try a simple mid-point detour (no ML).
    let detourApplied = false;
    if (!avoidance.ok && path.length >= 2) {
      const mid = {
        lat: (body.originLat + body.destLat) / 2 + 0.002,
        lng: (body.originLng + body.destLng) / 2 - 0.002,
      };
      const detourPath = [
        { lat: body.originLat, lng: body.originLng },
        mid,
        { lat: body.destLat, lng: body.destLng },
      ];
      const detourCheck = routeAvoidsReports(detourPath, reports, avoidRadiusM);
      if (detourCheck.ok || detourCheck.nearReportIds.length < avoidance.nearReportIds.length) {
        path = detourPath;
        distanceM = Math.round(
          haversineM(detourPath[0], detourPath[1]) +
            haversineM(detourPath[1], detourPath[2]),
        );
        detourApplied = true;
        Object.assign(avoidance, detourCheck);
      }
    }

    res.json({
      provider,
      mode: body.mode,
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
    });
  } catch (error) {
    next(error);
  }
});
