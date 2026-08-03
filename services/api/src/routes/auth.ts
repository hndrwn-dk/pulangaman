import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { mayClaimFirebaseUid, resolveSessionPhone } from './authIdentity.js';
import {
  allowLegacyChildRecovery,
  isLegacyFirebaseUid,
} from './authRecovery.js';

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

authRouter.post('/session', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const body = sessionBodySchema.parse(req.body);
    const firebaseUid = req.auth!.firebaseUid;
    // Identity phone comes from the verified token. Body phone is only a
    // fallback for dev-auth tokens that carry no phone_number claim.
    const phone = resolveSessionPhone({
      tokenPhone: req.auth?.phone,
      bodyPhone: body.phone,
    });
    if (!phone) {
      res.status(400).json({ error: 'phone_required' });
      return;
    }
    const digits = phoneDigits(phone);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Claim pending invite placeholder (pending:{…}) onto this Firebase identity.
      // Match by digit-normalized phone; never claim rows with a real Firebase UID.
      const pending = await client.query<{ id: string; firebase_uid: string }>(
        `SELECT id, firebase_uid FROM users
         WHERE regexp_replace(phone, '\\D', '', 'g') = $1
           AND firebase_uid LIKE 'pending:%'
         LIMIT 1
         FOR UPDATE`,
        [digits],
      );

      let userId: string;
      let claimedExisting = false;

      if (
        pending.rowCount &&
        pending.rows[0] &&
        mayClaimFirebaseUid(pending.rows[0].firebase_uid)
      ) {
        userId = pending.rows[0].id;
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
          // Do NOT rebind another account by phone digits — that enables
          // takeover when a client posts a victim phone with their own token.
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
          isLegacyFirebaseUid(legacyParent.rows[0].firebase_uid) &&
          allowLegacyChildRecovery({
            actorPhoneDigits: digits,
            recoverFromPhoneDigits: legacyDigits,
            legacyFirebaseUid: legacyParent.rows[0].firebase_uid,
          })
        ) {
          const moved = await client.query(
            `UPDATE parent_children
             SET parent_id = $1
             WHERE parent_id = $2
             RETURNING child_id`,
            [userId, legacyParent.rows[0].id],
          );
          recoveredChildren = moved.rowCount ?? 0;
          // Keep reminder ownership aligned with the recovered parent link.
          await client.query(
            `UPDATE child_reminders
             SET parent_id = $1, updated_at = now()
             WHERE parent_id = $2`,
            [userId, legacyParent.rows[0].id],
          );
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
