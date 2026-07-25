import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { computeSafeRoute } from '../services/safeRoute.js';

export const routesRouter = Router();

routesRouter.use(requireAuth, rateLimit);

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

    const result = await computeSafeRoute(body);
    res.json(result);
  } catch (error) {
    next(error);
  }
});
