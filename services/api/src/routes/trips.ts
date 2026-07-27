import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import {
  cancelTrip,
  createTrip,
  getOpenTrip,
  getTripById,
  mapTrip,
  markTripArrived,
  startTrip,
} from '../services/tripService.js';

export const tripsRouter = Router();
tripsRouter.use(requireAuth, rateLimit);

async function assertParentOfChild(parentId: string, childId: string): Promise<boolean> {
  const link = await pool.query(
    `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
    [parentId, childId],
  );
  return (link.rowCount ?? 0) > 0;
}

async function assertIsChild(userId: string): Promise<boolean> {
  const role = await pool.query(
    `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
    [userId],
  );
  return (role.rowCount ?? 0) > 0;
}

async function resolveParentId(childId: string): Promise<string | null> {
  const result = await pool.query<{ parent_id: string }>(
    `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
    [childId],
  );
  return result.rows[0]?.parent_id ?? null;
}

tripsRouter.get('/active', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    let childId = typeof req.query.childId === 'string' ? req.query.childId : null;
    if (!childId) {
      if (!(await assertIsChild(userId))) {
        res.status(400).json({ error: 'child_id_required' });
        return;
      }
      childId = userId;
    } else if (childId !== userId) {
      if (!(await assertParentOfChild(userId, childId))) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }
    }

    const trip = await getOpenTrip(childId);
    res.json({ trip: trip ? mapTrip(trip) : null });
  } catch (error) {
    next(error);
  }
});

tripsRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid().optional(),
        fromZoneId: z.string().uuid(),
        toZoneId: z.string().uuid(),
        mode: z.enum(['walking', 'driving']).optional(),
        startImmediately: z.boolean().optional(),
      })
      .parse(req.body);

    const isChild = await assertIsChild(userId);
    let childId: string;
    let parentId: string;
    let createdBy: 'parent' | 'child';

    if (isChild) {
      childId = userId;
      const pid = await resolveParentId(childId);
      if (!pid) {
        res.status(400).json({ error: 'parent_link_required' });
        return;
      }
      parentId = pid;
      createdBy = 'child';
    } else {
      if (!body.childId) {
        res.status(400).json({ error: 'child_id_required' });
        return;
      }
      if (!(await assertParentOfChild(userId, body.childId))) {
        res.status(403).json({ error: 'forbidden' });
        return;
      }
      childId = body.childId;
      parentId = userId;
      createdBy = 'parent';
    }

    const result = await createTrip({
      childId,
      parentId,
      fromZoneId: body.fromZoneId,
      toZoneId: body.toZoneId,
      createdBy,
      mode: body.mode,
      startImmediately: body.startImmediately ?? createdBy === 'child',
    });

    if (!result.ok) {
      const status =
        result.error === 'trip_already_open'
          ? 409
          : result.error === 'zone_not_found' || result.error === 'zone_child_mismatch'
            ? 404
            : 400;
      res.status(status).json({ error: result.error });
      return;
    }

    res.status(201).json({ trip: mapTrip(result.trip) });
  } catch (error) {
    next(error);
  }
});

tripsRouter.post('/:id/start', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const tripId = String(req.params.id);
    const trip = await getTripById(tripId);
    if (!trip) {
      res.status(404).json({ error: 'not_found' });
      return;
    }

    const isChild = trip.child_id === userId;
    const isParent = await assertParentOfChild(userId, trip.child_id);
    if (!isChild && !isParent) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }

    const result = await startTrip(trip.id);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json({ trip: mapTrip(result.trip) });
  } catch (error) {
    next(error);
  }
});

tripsRouter.post('/:id/arrive', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const tripId = String(req.params.id);
    const trip = await getTripById(tripId);
    if (!trip) {
      res.status(404).json({ error: 'not_found' });
      return;
    }

    const isChild = trip.child_id === userId;
    const isParent = await assertParentOfChild(userId, trip.child_id);
    if (!isChild && !isParent) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }

    const result = await markTripArrived(trip.id, userId);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json({ trip: mapTrip(result.trip) });
  } catch (error) {
    next(error);
  }
});

tripsRouter.post('/:id/cancel', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const tripId = String(req.params.id);
    const trip = await getTripById(tripId);
    if (!trip) {
      res.status(404).json({ error: 'not_found' });
      return;
    }

    const isChild = trip.child_id === userId;
    const isParent = await assertParentOfChild(userId, trip.child_id);
    if (!isChild && !isParent) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }

    const result = await cancelTrip(trip.id, userId);
    if (!result.ok) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json({ trip: mapTrip(result.trip) });
  } catch (error) {
    next(error);
  }
});
