import type { NextFunction, Request, Response } from 'express';
import { config } from '../config.js';
import { verifyAppCheckToken } from '../firebase/admin.js';

export async function requireAppCheck(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const token = req.header('X-Firebase-AppCheck');
  if (!token) {
    if (!config.APP_CHECK_ENFORCE) {
      console.warn('app_check_missing', { path: req.path });
      next();
      return;
    }
    res.status(401).json({ error: 'app_check_required' });
    return;
  }
  try {
    await verifyAppCheckToken(token);
    next();
  } catch {
    if (!config.APP_CHECK_ENFORCE) {
      console.warn('app_check_invalid_monitor_mode', { path: req.path });
      next();
      return;
    }
    res.status(401).json({ error: 'app_check_invalid' });
  }
}
