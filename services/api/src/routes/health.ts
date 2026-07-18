import { Router } from 'express';
import { checkDatabase } from '../db/pool.js';
import { checkRedis } from '../redis/client.js';
import { isFirebaseConfigured } from '../config.js';

export const healthRouter = Router();

healthRouter.get('/health', async (_req, res) => {
  const status = {
    ok: true,
    service: 'pulangaman-api',
    firebaseConfigured: isFirebaseConfigured,
    database: false,
    redis: false,
  };

  try {
    status.database = await checkDatabase();
  } catch {
    status.ok = false;
  }

  try {
    status.redis = await checkRedis();
  } catch {
    status.ok = false;
  }

  res.status(status.ok ? 200 : 503).json(status);
});

healthRouter.get('/ready', async (_req, res) => {
  try {
    await checkDatabase();
    res.json({ ready: true });
  } catch {
    res.status(503).json({ ready: false });
  }
});
