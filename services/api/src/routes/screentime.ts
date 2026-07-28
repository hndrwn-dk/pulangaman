import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { isParentOfChild } from '../middleware/roles.js';
import { getOrCreateScreenTimeInsight } from '../services/screentimeInsights.js';

export const screentimeRouter = Router();
screentimeRouter.use(requireAuth, rateLimit);

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
