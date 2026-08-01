import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import {
  getLatestDigestForParent,
  markDigestOpened,
} from '../services/weeklyDigest.js';

export const weeklyDigestRouter = Router();
weeklyDigestRouter.use(requireAuth, rateLimit);

weeklyDigestRouter.get('/latest', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'parent_required' });
      return;
    }
    const digest = await getLatestDigestForParent(parentId);
    res.json({ digest });
  } catch (error) {
    next(error);
  }
});

weeklyDigestRouter.post('/:digestId/opened', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const digestId = z.string().uuid().parse(req.params.digestId);
    if (!parentId) {
      res.status(403).json({ error: 'parent_required' });
      return;
    }
    const ok = await markDigestOpened(parentId, digestId);
    res.json({ opened: ok });
  } catch (error) {
    next(error);
  }
});
