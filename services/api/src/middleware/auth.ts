import type { NextFunction, Request, Response } from 'express';
import { verifyIdToken } from '../firebase/admin.js';
import { pool } from '../db/pool.js';

export type AuthedRequest = Request & {
  auth?: {
    firebaseUid: string;
    userId?: string;
    phone?: string;
  };
};

export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  try {
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'missing_bearer_token' });
      return;
    }

    const token = header.slice('Bearer '.length).trim();
    const verified = await verifyIdToken(token);

    const userResult = await pool.query<{ id: string }>(
      'SELECT id FROM users WHERE firebase_uid = $1 AND is_active = true LIMIT 1',
      [verified.uid],
    );

    req.auth = {
      firebaseUid: verified.uid,
      userId: userResult.rows[0]?.id,
      phone: verified.phone,
    };

    next();
  } catch (error) {
    console.error('auth_failed', error);
    res.status(401).json({ error: 'invalid_token' });
  }
}
