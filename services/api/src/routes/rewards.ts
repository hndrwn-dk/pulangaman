import { randomUUID } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { isParentOfChild } from '../middleware/roles.js';
import { awardReward } from '../services/rewards.js';

export const rewardsRouter = Router();
rewardsRouter.use(requireAuth, rateLimit);

async function canView(userId: string, childId: string): Promise<boolean> {
  return userId === childId || isParentOfChild(userId, childId);
}

rewardsRouter.get('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!userId || !(await canView(userId, childId))) {
      res.status(403).json({ error: 'child_access_required' });
      return;
    }
    const balance = await pool.query(
      `SELECT points, current_streak, longest_streak, last_award_date
       FROM reward_balances WHERE child_id = $1`,
      [childId],
    );
    const ledger = await pool.query(
      `SELECT id, delta, reason, metadata, created_at
       FROM reward_ledger
       WHERE child_id = $1
       ORDER BY created_at DESC
       LIMIT 30`,
      [childId],
    );
    res.json({
      balance: balance.rows[0] ?? {
        points: 0,
        current_streak: 0,
        longest_streak: 0,
        last_award_date: null,
      },
      ledger: ledger.rows,
    });
  } catch (error) {
    next(error);
  }
});

rewardsRouter.post('/:childId/adjust', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    const body = z
      .object({
        delta: z.number().int().min(-1000).max(1000).refine((value) => value !== 0),
        reason: z.string().min(1).max(120),
      })
      .parse(req.body);
    if (!parentId || !(await isParentOfChild(parentId, childId))) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }
    await awardReward({
      childId,
      actorId: parentId,
      delta: body.delta,
      reason: body.reason,
      referenceKey: `parent-adjust:${randomUUID()}`,
    });
    res.status(201).json({ awarded: true });
  } catch (error) {
    next(error);
  }
});
