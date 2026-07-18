import type { NextFunction, Response } from 'express';
import { config } from '../config.js';
import type { AuthedRequest } from './auth.js';

type Bucket = { count: number; resetAt: number };

const buckets = new Map<string, Bucket>();

export function rateLimit(req: AuthedRequest, res: Response, next: NextFunction): void {
  const key = req.auth?.userId ?? req.auth?.firebaseUid ?? req.ip ?? 'anon';
  const now = Date.now();
  const windowMs = 60_000;
  let bucket = buckets.get(key);

  if (!bucket || now >= bucket.resetAt) {
    bucket = { count: 0, resetAt: now + windowMs };
    buckets.set(key, bucket);
  }

  bucket.count += 1;
  res.setHeader('X-RateLimit-Limit', String(config.RATE_LIMIT_PER_MINUTE));
  res.setHeader(
    'X-RateLimit-Remaining',
    String(Math.max(0, config.RATE_LIMIT_PER_MINUTE - bucket.count)),
  );

  if (bucket.count > config.RATE_LIMIT_PER_MINUTE) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }

  next();
}
