import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';

export const placesRouter = Router();
placesRouter.use(requireAuth, rateLimit);

type PlaceHit = {
  placeId: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
};

placesRouter.get('/search', async (req: AuthedRequest, res, next) => {
  try {
    if (!req.auth?.userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const q = z.string().min(2).max(200).parse(String(req.query.q ?? '').trim());
    if (!config.GOOGLE_MAPS_API_KEY) {
      res.status(503).json({
        error: 'maps_key_missing',
        message: 'GOOGLE_MAPS_API_KEY belum di-set di server.',
      });
      return;
    }

    const url = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
    url.searchParams.set('query', q);
    url.searchParams.set('key', config.GOOGLE_MAPS_API_KEY);
    url.searchParams.set('language', 'id');

    const response = await fetch(url);
    const data = (await response.json()) as {
      status: string;
      error_message?: string;
      results?: Array<{
        place_id: string;
        name: string;
        formatted_address?: string;
        geometry?: { location?: { lat: number; lng: number } };
      }>;
    };

    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      res.status(502).json({
        error: 'places_upstream',
        status: data.status,
        message: data.error_message ?? data.status,
      });
      return;
    }

    const places: PlaceHit[] = (data.results ?? [])
      .filter((r) => r.geometry?.location)
      .slice(0, 8)
      .map((r) => ({
        placeId: r.place_id,
        name: r.name,
        address: r.formatted_address ?? r.name,
        lat: r.geometry!.location!.lat,
        lng: r.geometry!.location!.lng,
      }));

    res.json({ places });
  } catch (error) {
    next(error);
  }
});

placesRouter.get('/reverse', async (req: AuthedRequest, res, next) => {
  try {
    if (!req.auth?.userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const lat = z.coerce.number().min(-90).max(90).parse(req.query.lat);
    const lng = z.coerce.number().min(-180).max(180).parse(req.query.lng);

    if (!config.GOOGLE_MAPS_API_KEY) {
      res.json({
        label: `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
        address: null,
      });
      return;
    }

    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('latlng', `${lat},${lng}`);
    url.searchParams.set('key', config.GOOGLE_MAPS_API_KEY);
    url.searchParams.set('language', 'id');

    const response = await fetch(url);
    const data = (await response.json()) as {
      status: string;
      results?: Array<{ formatted_address?: string; name?: string }>;
    };

    const address = data.results?.[0]?.formatted_address ?? null;
    res.json({
      label: address ?? `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
      address,
    });
  } catch (error) {
    next(error);
  }
});
