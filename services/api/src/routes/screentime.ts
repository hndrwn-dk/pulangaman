import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { isParentOfChild } from '../middleware/roles.js';
import { getOrCreateScreenTimeInsight } from '../services/screentimeInsights.js';
import {
  listChildrenForParent,
  seedScreenTimeForChildren,
} from '../services/seedScreenTime.js';

export const screentimeRouter = Router();
screentimeRouter.use(requireAuth, rateLimit);

/**
 * POST /api/v1/screentime/seed-demo
 * Parent-only demo seed: ~35 days usage + hourly peaks for linked children.
 * Idempotent via client_event_id upserts; clears today's insights cache.
 */
screentimeRouter.post('/seed-demo', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'parent_profile_required' });
      return;
    }

    const body = z
      .object({
        days: z.number().int().min(14).max(42).optional(),
        childIds: z.array(z.string().uuid()).optional(),
        limitMinutes: z.number().int().min(30).max(480).optional(),
      })
      .parse(req.body ?? {});

    const linked = await listChildrenForParent(pool, parentId);
    if (linked.length === 0) {
      res.status(404).json({ error: 'no_children' });
      return;
    }

    let targets = linked;
    if (body.childIds && body.childIds.length > 0) {
      const allowed = new Set(linked.map((c) => c.id));
      const filtered = body.childIds.filter((id) => allowed.has(id));
      if (filtered.length === 0) {
        res.status(403).json({ error: 'parent_access_required' });
        return;
      }
      targets = linked.filter((c) => filtered.includes(c.id));
    }

    const seeded = await seedScreenTimeForChildren(pool, {
      childIds: targets.map((c) => c.id),
      days: body.days,
      limitMinutes: body.limitMinutes,
    });

    res.status(201).json({
      children: targets.map((c) => ({ id: c.id, name: c.name })),
      results: seeded,
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/screentime/:childId/insights?lang=id|en
 * Parent-only. Template phrasing cached once per child per Jakarta calendar day.
 */
screentimeRouter.get('/:childId/insights', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId) {
      res.status(403).json({ error: 'parent_profile_required' });
      return;
    }
    if (!(await isParentOfChild(parentId, childId))) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }

    const lang = typeof req.query.lang === 'string' ? req.query.lang : undefined;
    const insight = await getOrCreateScreenTimeInsight(childId, lang);
    res.json({
      date: insight.date,
      trendText: insight.trendText,
      patternText: insight.patternText,
      patternDayText: insight.patternDayText,
      streakText: insight.streakText,
      suggestedReminderTime: insight.suggestedReminderTime,
      suggestedReminderLabel: insight.suggestedReminderLabel,
      daysUnderLimit: insight.daysUnderLimit,
      totalDays: insight.totalDays,
      source: insight.source,
      locale: insight.locale,
      generatedAt: insight.generatedAt,
    });
  } catch (error) {
    next(error);
  }
});
