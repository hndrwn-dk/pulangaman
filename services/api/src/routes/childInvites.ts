import { randomBytes, randomUUID } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { createChildCustomToken, ensureFirebaseUser } from '../firebase/admin.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';

export const childInvitesRouter = Router();

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const INVITE_TTL_HOURS = 24;

function generateInviteCode(): string {
  const bytes = randomBytes(6);
  let code = '';
  for (let i = 0; i < 6; i += 1) {
    code += CODE_ALPHABET[bytes[i]! % CODE_ALPHABET.length];
  }
  return code;
}

function normalizeCode(raw: string): string {
  return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
}

/** Parent creates a short invite code for a child device to join. */
childInvitesRouter.post('/', requireAuth, rateLimit, async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        childDisplayName: z.string().min(1).max(120).optional(),
        /** If set, redeeming reuses this child account instead of creating a new one. */
        relinkChildId: z.string().uuid().optional(),
      })
      .parse(req.body ?? {});

    const role = await pool.query(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'parent'`,
      [parentId],
    );
    if (role.rowCount === 0) {
      res.status(403).json({ error: 'parent_role_required' });
      return;
    }

    let relinkName: string | null = body.childDisplayName ?? null;
    if (body.relinkChildId) {
      const link = await pool.query<{ name: string }>(
        `SELECT u.name
         FROM parent_children pc
         JOIN users u ON u.id = pc.child_id
         WHERE pc.parent_id = $1 AND pc.child_id = $2`,
        [parentId, body.relinkChildId],
      );
      if (link.rowCount === 0) {
        res.status(404).json({ error: 'child_not_found' });
        return;
      }
      relinkName = relinkName ?? link.rows[0].name;
    }

    let code = generateInviteCode();
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);
      try {
        const result = await pool.query<{
          id: string;
          code: string;
          expires_at: Date;
        }>(
          `INSERT INTO child_invites
             (parent_id, code, child_display_name, expires_at, relink_child_id)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, code, expires_at`,
          [
            parentId,
            code,
            relinkName,
            expiresAt.toISOString(),
            body.relinkChildId ?? null,
          ],
        );
        await pool.query(
          `INSERT INTO audit_events (actor_id, action, payload)
           VALUES ($1, 'child_invite.created', $2::jsonb)`,
          [
            parentId,
            JSON.stringify({
              inviteId: result.rows[0].id,
              code,
              relinkChildId: body.relinkChildId ?? null,
            }),
          ],
        );
        res.status(201).json({
          id: result.rows[0].id,
          code: result.rows[0].code,
          expiresAt: result.rows[0].expires_at,
          childDisplayName: relinkName,
          relinkChildId: body.relinkChildId ?? null,
        });
        return;
      } catch (error) {
        const pgError = error as { code?: string };
        if (pgError.code === '23505') {
          code = generateInviteCode();
          continue;
        }
        throw error;
      }
    }
    res.status(500).json({ error: 'invite_code_exhausted' });
  } catch (error) {
    next(error);
  }
});

/** Parent lists recent invites. */
childInvitesRouter.get('/', requireAuth, rateLimit, async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    await pool.query(
      `UPDATE child_invites
       SET status = 'expired'
       WHERE parent_id = $1 AND status = 'pending' AND expires_at < now()`,
      [parentId],
    );

    const result = await pool.query(
      `SELECT id, code, child_display_name, status, expires_at, redeemed_at, created_at
       FROM child_invites
       WHERE parent_id = $1
       ORDER BY created_at DESC
       LIMIT 20`,
      [parentId],
    );
    res.json({ invites: result.rows });
  } catch (error) {
    next(error);
  }
});

/**
 * Child joins via invite code (no prior auth).
 * Creates child user + parent_children link, OR reuses existing child when invite has relink_child_id.
 */
childInvitesRouter.post('/join', rateLimit, async (req, res, next) => {
  try {
    const body = z
      .object({
        code: z.string().min(4).max(16),
        name: z.string().min(1).max(120),
      })
      .parse(req.body);

    const code = normalizeCode(body.code);
    if (code.length < 4) {
      res.status(400).json({ error: 'invalid_invite_code' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE child_invites
         SET status = 'expired'
         WHERE code = $1 AND status = 'pending' AND expires_at < now()`,
        [code],
      );

      const invite = await client.query<{
        id: string;
        parent_id: string;
        child_display_name: string | null;
        relink_child_id: string | null;
      }>(
        `SELECT id, parent_id, child_display_name, relink_child_id
         FROM child_invites
         WHERE code = $1 AND status = 'pending'
         FOR UPDATE`,
        [code],
      );
      if (invite.rowCount === 0) {
        await client.query('ROLLBACK');
        res.status(404).json({ error: 'invite_not_found_or_used' });
        return;
      }

      const inviteRow = invite.rows[0];
      const displayName = body.name.trim() || inviteRow.child_display_name || 'Anak';

      let childId: string;
      let firebaseUid: string;

      if (inviteRow.relink_child_id) {
        const existing = await client.query<{ id: string; name: string }>(
          `SELECT u.id, u.name
           FROM users u
           JOIN parent_children pc ON pc.child_id = u.id
           WHERE u.id = $1 AND pc.parent_id = $2
           FOR UPDATE`,
          [inviteRow.relink_child_id, inviteRow.parent_id],
        );
        if (existing.rowCount === 0) {
          await client.query('ROLLBACK');
          res.status(404).json({ error: 'relink_child_not_found' });
          return;
        }
        childId = existing.rows[0].id;
        firebaseUid = `child_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
        await client.query(
          `UPDATE users
           SET firebase_uid = $2,
               name = COALESCE(NULLIF($3, ''), name),
               updated_at = now()
           WHERE id = $1`,
          [childId, firebaseUid, displayName],
        );
      } else {
        firebaseUid = `child_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
        const phone = `invite:${code.toLowerCase()}`;
        const child = await client.query<{ id: string }>(
          `INSERT INTO users (firebase_uid, phone, name)
           VALUES ($1, $2, $3)
           RETURNING id`,
          [firebaseUid, phone, displayName],
        );
        childId = child.rows[0].id;

        await client.query(
          `INSERT INTO user_roles (user_id, role) VALUES ($1, 'child')`,
          [childId],
        );
        await client.query(
          `INSERT INTO child_profiles (user_id) VALUES ($1)`,
          [childId],
        );
        await client.query(
          `INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)`,
          [inviteRow.parent_id, childId],
        );
      }

      await client.query(
        `UPDATE child_invites
         SET status = 'redeemed',
             redeemed_by_child_id = $2,
             redeemed_at = now()
         WHERE id = $1`,
        [inviteRow.id, childId],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'child_invite.redeemed', $3::jsonb)`,
        [
          childId,
          childId,
          JSON.stringify({
            inviteId: inviteRow.id,
            parentId: inviteRow.parent_id,
            code,
            relinked: Boolean(inviteRow.relink_child_id),
          }),
        ],
      );

      await ensureFirebaseUser({
        uid: firebaseUid,
        displayName,
      });
      const tokenResult = await createChildCustomToken(firebaseUid);

      await client.query('COMMIT');

      res.status(201).json({
        userId: childId,
        firebaseUid,
        role: 'child',
        name: displayName,
        parentId: inviteRow.parent_id,
        relinked: Boolean(inviteRow.relink_child_id),
        customToken: tokenResult.customToken,
        /** Dev-auth token: Bearer dev:<firebaseUid> */
        tokenHint: `dev:${firebaseUid}`,
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

/** Parent revokes a pending invite. */
childInvitesRouter.post(
  '/:id/revoke',
  requireAuth,
  rateLimit,
  async (req: AuthedRequest, res, next) => {
    try {
      const parentId = req.auth?.userId;
      const inviteId = String(req.params.id);
      if (!parentId) {
        res.status(403).json({ error: 'user_profile_required' });
        return;
      }
      const result = await pool.query(
        `UPDATE child_invites
         SET status = 'revoked'
         WHERE id = $1 AND parent_id = $2 AND status = 'pending'
         RETURNING id, code, status`,
        [inviteId, parentId],
      );
      if (result.rowCount === 0) {
        res.status(404).json({ error: 'invite_not_found' });
        return;
      }
      res.json(result.rows[0]);
    } catch (error) {
      next(error);
    }
  },
);
