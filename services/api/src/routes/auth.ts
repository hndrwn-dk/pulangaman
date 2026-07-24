import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';

export const authRouter = Router();

const sessionBodySchema = z.object({
  name: z.string().min(1).max(120),
  phone: z.string().min(8).max(20).optional(),
  email: z.string().email().optional(),
  role: z.enum(['parent', 'child', 'guardian', 'school_admin']).default('parent'),
  /**
   * Optional: recover children from a previous parent account (dev-auth / old phone)
   * after switching to Firebase OTP with a different number.
   */
  recoverFromPhone: z.string().min(8).max(20).optional(),
});

/** Digits only, strip leading 0 after country assumption handled by caller. */
export function phoneDigits(raw: string): string {
  return raw.replace(/\D/g, '');
}

function isLegacyFirebaseUid(uid: string): boolean {
  return (
    uid.startsWith('parent_') ||
    uid.startsWith('guardian_') ||
    uid.startsWith('child_') ||
    uid.startsWith('dev:') ||
    uid.startsWith('pending:')
  );
}

authRouter.post('/session', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const body = sessionBodySchema.parse(req.body);
    const firebaseUid = req.auth!.firebaseUid;
    const phone = body.phone ?? req.auth?.phone;
    if (!phone) {
      res.status(400).json({ error: 'phone_required' });
      return;
    }
    const digits = phoneDigits(phone);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Claim pending invite placeholder (pending:{phone}) onto this Firebase identity.
      const pending = await client.query<{ id: string }>(
        `SELECT id FROM users
         WHERE phone = $1 AND firebase_uid = $2
         LIMIT 1`,
        [phone, `pending:${phone}`],
      );

      let userId: string;
      let claimedExisting = false;

      if (pending.rowCount && pending.rows[0]) {
        userId = pending.rows[0].id;
        await client.query(
          `UPDATE users
           SET firebase_uid = $2,
               email = COALESCE($3, email),
               name = $4,
               updated_at = now()
           WHERE id = $1`,
          [userId, firebaseUid, body.email ?? null, body.name],
        );
        claimedExisting = true;
      } else {
        // Already bound to this Firebase UID?
        const byUid = await client.query<{ id: string }>(
          `SELECT id FROM users WHERE firebase_uid = $1 LIMIT 1`,
          [firebaseUid],
        );

        if (byUid.rowCount && byUid.rows[0]) {
          userId = byUid.rows[0].id;
          await client.query(
            `UPDATE users
             SET phone = $2,
                 email = COALESCE($3, email),
                 name = $4,
                 updated_at = now()
             WHERE id = $1`,
            [userId, phone, body.email ?? null, body.name],
          );
        } else {
          // Claim existing account with same verified phone (OTP / legacy digits).
          const byPhone = await client.query<{ id: string; firebase_uid: string }>(
            `SELECT id, firebase_uid FROM users
             WHERE regexp_replace(phone, '\\D', '', 'g') = $1
             ORDER BY updated_at DESC
             LIMIT 1`,
            [digits],
          );

          if (byPhone.rowCount && byPhone.rows[0]) {
            userId = byPhone.rows[0].id;
            const previousUid = byPhone.rows[0].firebase_uid;
            if (previousUid !== firebaseUid) {
              await client.query(
                `UPDATE users
                 SET firebase_uid = $2,
                     phone = $3,
                     email = COALESCE($4, email),
                     name = $5,
                     updated_at = now()
                 WHERE id = $1`,
                [userId, firebaseUid, phone, body.email ?? null, body.name],
              );
              claimedExisting = true;
            }
          } else {
            const upsert = await client.query<{ id: string }>(
              `INSERT INTO users (firebase_uid, phone, email, name)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (firebase_uid) DO UPDATE
                 SET phone = EXCLUDED.phone,
                     email = COALESCE(EXCLUDED.email, users.email),
                     name = EXCLUDED.name,
                     updated_at = now()
               RETURNING id`,
              [firebaseUid, phone, body.email ?? null, body.name],
            );
            userId = upsert.rows[0].id;
          }
        }
      }

      await client.query(
        `INSERT INTO user_roles (user_id, role)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [userId, body.role],
      );

      if (body.role === 'child') {
        await client.query(
          `INSERT INTO child_profiles (user_id)
           VALUES ($1)
           ON CONFLICT DO NOTHING`,
          [userId],
        );
      }

      if (body.role === 'guardian') {
        await client.query(
          `INSERT INTO guardian_profiles (user_id)
           VALUES ($1)
           ON CONFLICT DO NOTHING`,
          [userId],
        );
      }

      let recoveredChildren = 0;
      if (
        body.role === 'parent' &&
        body.recoverFromPhone &&
        phoneDigits(body.recoverFromPhone) !== digits
      ) {
        const legacyDigits = phoneDigits(body.recoverFromPhone);
        const legacyParent = await client.query<{
          id: string;
          firebase_uid: string;
        }>(
          `SELECT u.id, u.firebase_uid
           FROM users u
           JOIN user_roles r ON r.user_id = u.id AND r.role = 'parent'
           WHERE regexp_replace(u.phone, '\\D', '', 'g') = $1
             AND u.id <> $2
           ORDER BY u.updated_at DESC
           LIMIT 1`,
          [legacyDigits, userId],
        );

        if (
          legacyParent.rowCount &&
          legacyParent.rows[0] &&
          isLegacyFirebaseUid(legacyParent.rows[0].firebase_uid)
        ) {
          const moved = await client.query(
            `UPDATE parent_children
             SET parent_id = $1
             WHERE parent_id = $2
             RETURNING child_id`,
            [userId, legacyParent.rows[0].id],
          );
          recoveredChildren = moved.rowCount ?? 0;
          await client.query(
            `INSERT INTO audit_events (actor_id, action, payload)
             VALUES ($1, 'auth.recover_children', $2::jsonb)`,
            [
              userId,
              JSON.stringify({
                fromParentId: legacyParent.rows[0].id,
                fromPhoneDigits: legacyDigits,
                count: recoveredChildren,
              }),
            ],
          );
        }
      }

      await client.query(
        `INSERT INTO audit_events (actor_id, action, payload)
         VALUES ($1, 'auth.session', $2::jsonb)`,
        [
          userId,
          JSON.stringify({
            role: body.role,
            claimedExisting,
            recoveredChildren,
          }),
        ],
      );

      await client.query('COMMIT');

      res.status(201).json({
        userId,
        firebaseUid,
        role: body.role,
        claimedExisting,
        recoveredChildren,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});
