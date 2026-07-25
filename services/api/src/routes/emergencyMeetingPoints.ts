import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import {
  applyPrimaryToChildren,
  activateMeetingPoints,
  createPoint,
  deleteAllPointsForParent,
  deletePoint,
  getActiveActivationForParent,
  getActiveAlertForChild,
  getChildPointStatus,
  getPointById,
  listPointsForChild,
  mapPoint,
  resolveActivations,
  updatePoint,
} from '../services/emergencyMeetingService.js';

export const emergencyMeetingRouter = Router();
emergencyMeetingRouter.use(requireAuth, rateLimit);

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

emergencyMeetingRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    let childId: string;
    if (typeof req.query.childId === 'string' && req.query.childId.length > 0) {
      childId = z.string().uuid().parse(req.query.childId);
      if (childId !== userId && !(await assertParentOfChild(userId, childId))) {
        res.status(404).json({ error: 'child_not_found' });
        return;
      }
    } else if (await assertIsChild(userId)) {
      childId = userId;
    } else {
      res.status(400).json({ error: 'child_id_required' });
      return;
    }

    const points = await listPointsForChild(childId);
    res.json({ points: points.map(mapPoint) });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid(),
        name: z.string().min(1).max(120),
        lat: z.number().min(-90).max(90),
        lng: z.number().min(-180).max(180),
        instructions: z.string().max(500).nullable().optional(),
        isPrimary: z.boolean().optional(),
      })
      .parse(req.body);

    if (!(await assertParentOfChild(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const point = await createPoint({
      childId: body.childId,
      parentId,
      name: body.name,
      lat: body.lat,
      lng: body.lng,
      instructions: body.instructions,
      isPrimary: body.isPrimary,
    });
    res.status(201).json({ point: mapPoint(point) });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.post('/apply-to-all', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        sourceChildId: z.string().uuid(),
        targetChildIds: z.array(z.string().uuid()).min(1),
      })
      .parse(req.body);

    if (!(await assertParentOfChild(parentId, body.sourceChildId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }
    for (const id of body.targetChildIds) {
      if (!(await assertParentOfChild(parentId, id))) {
        res.status(404).json({ error: 'child_not_found', childId: id });
        return;
      }
    }

    try {
      const result = await applyPrimaryToChildren({
        parentId,
        sourceChildId: body.sourceChildId,
        targetChildIds: body.targetChildIds,
      });
      res.json(result);
    } catch (e) {
      if (e instanceof Error && e.message === 'source_point_not_found') {
        res.status(404).json({ error: 'source_point_not_found' });
        return;
      }
      throw e;
    }
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.post('/activate', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        note: z.string().max(280).nullable().optional(),
      })
      .parse(req.body ?? {});

    try {
      const result = await activateMeetingPoints({
        parentId,
        note: body.note,
      });
      res.status(201).json(result);
    } catch (e) {
      if (e instanceof Error && e.message === 'activation_rate_limited') {
        res.status(429).json({ error: 'activation_rate_limited' });
        return;
      }
      throw e;
    }
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.get('/activation', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const activation = await getActiveActivationForParent(parentId);
    res.json({ activation });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.post('/deactivate', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await resolveActivations({ parentId });
    res.json({ ok: true, ...result });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.get('/active', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (!(await assertIsChild(userId))) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }

    const alert = await getActiveAlertForChild(userId);
    res.json({ alert });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.get('/:childId/status', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const childId = z.string().uuid().parse(req.params.childId);
    if (childId !== userId && !(await assertParentOfChild(userId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const status = await getChildPointStatus(childId);
    res.json(status);
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.put('/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const id = z.string().uuid().parse(req.params.id);
    const existing = await getPointById(id);
    if (!existing || !(await assertParentOfChild(parentId, existing.child_id))) {
      res.status(404).json({ error: 'not_found' });
      return;
    }

    const body = z
      .object({
        name: z.string().min(1).max(120).optional(),
        lat: z.number().min(-90).max(90).optional(),
        lng: z.number().min(-180).max(180).optional(),
        instructions: z.string().max(500).nullable().optional(),
        isPrimary: z.boolean().optional(),
      })
      .parse(req.body);

    const point = await updatePoint({ id, ...body });
    res.json({ point: point ? mapPoint(point) : null });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.delete('/clear-all', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const deleted = await deleteAllPointsForParent(parentId);
    res.json({ ok: true, deleted });
  } catch (error) {
    next(error);
  }
});

emergencyMeetingRouter.delete('/:id', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const id = z.string().uuid().parse(req.params.id);
    const existing = await getPointById(id);
    if (!existing || !(await assertParentOfChild(parentId, existing.child_id))) {
      res.status(404).json({ error: 'not_found' });
      return;
    }

    await deletePoint(id);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});
