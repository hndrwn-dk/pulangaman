import { randomBytes } from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import {
  canManageChildFeatures,
  type GuardianAccessLevel,
} from '../middleware/roles.js';

export const guardianInvitesRouter = Router();

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const INVITE_TTL_HOURS = 24;

const accessLevelSchema = z.enum(['view', 'co_parent']);

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

function toIsoUtc(value: Date | string): string {
  if (value instanceof Date) return value.toISOString();
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toISOString();
}

/** Parent / co-parent creates a short invite code for a guardian. */
guardianInvitesRouter.post('/', requireAuth, rateLimit, async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid(),
        accessLevel: accessLevelSchema.default('view'),
        guardianDisplayName: z.string().min(1).max(120).optional(),
      })
      .parse(req.body ?? {});

    if (!(await canManageChildFeatures(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const child = await pool.query<{ name: string }>(
      `SELECT name FROM users WHERE id = $1`,
      [body.childId],
    );
    const childName = child.rows[0]?.name ?? null;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE guardian_invites
         SET status = 'expired'
         WHERE parent_id = $1
           AND status = 'pending'
           AND (
             expires_at <= now()
             OR created_at <= now() - ($2::int * interval '1 hour')
           )`,
        [parentId, INVITE_TTL_HOURS],
      );

      // At most one pending code per child for this parent.
      await client.query(
        `UPDATE guardian_invites
         SET status = 'revoked'
         WHERE parent_id = $1
           AND child_id = $2
           AND status = 'pending'`,
        [parentId, body.childId],
      );

      let code = generateInviteCode();
      for (let attempt = 0; attempt < 5; attempt += 1) {
        const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);
        try {
          const result = await client.query<{
            id: string;
            code: string;
            expires_at: Date;
            created_at: Date;
            access_level: GuardianAccessLevel;
          }>(
            `INSERT INTO guardian_invites
               (parent_id, child_id, code, guardian_display_name, access_level, expires_at)
             VALUES ($1, $2, $3, $4, $5::guardian_access_level, $6)
             RETURNING id, code, expires_at, created_at, access_level`,
            [
              parentId,
              body.childId,
              code,
              body.guardianDisplayName ?? null,
              body.accessLevel,
              expiresAt.toISOString(),
            ],
          );
          await client.query(
            `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
             VALUES ($1, $2, 'guardian_invite.created', $3::jsonb)`,
            [
              parentId,
              body.childId,
              JSON.stringify({
                inviteId: result.rows[0].id,
                code,
                accessLevel: body.accessLevel,
              }),
            ],
          );
          await client.query('COMMIT');
          res.status(201).json({
            id: result.rows[0].id,
            code: result.rows[0].code,
            expiresAt: toIsoUtc(result.rows[0].expires_at),
            createdAt: toIsoUtc(result.rows[0].created_at),
            childId: body.childId,
            childName,
            accessLevel: result.rows[0].access_level,
            guardianDisplayName: body.guardianDisplayName ?? null,
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
      await client.query('ROLLBACK');
      res.status(500).json({ error: 'invite_code_exhausted' });
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

/** Parent lists pending guardian invite codes. */
guardianInvitesRouter.get('/', requireAuth, rateLimit, async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    await pool.query(
      `UPDATE guardian_invites
       SET status = 'expired'
       WHERE parent_id = $1
         AND status = 'pending'
         AND (
           expires_at <= now()
           OR created_at <= now() - ($2::int * interval '1 hour')
         )`,
      [parentId, INVITE_TTL_HOURS],
    );

    const result = await pool.query<{
      id: string;
      code: string;
      child_id: string;
      child_name: string;
      guardian_display_name: string | null;
      access_level: GuardianAccessLevel;
      status: string;
      expires_at: Date;
      created_at: Date;
    }>(
      `SELECT gi.id, gi.code, gi.child_id, u.name AS child_name,
              gi.guardian_display_name, gi.access_level, gi.status,
              gi.expires_at, gi.created_at
       FROM guardian_invites gi
       JOIN users u ON u.id = gi.child_id
       WHERE gi.parent_id = $1
         AND gi.status = 'pending'
         AND gi.expires_at > now()
         AND gi.created_at > now() - ($2::int * interval '1 hour')
       ORDER BY gi.created_at DESC
       LIMIT 20`,
      [parentId, INVITE_TTL_HOURS],
    );

    res.json({
      invites: result.rows.map((row) => ({
        id: row.id,
        code: row.code,
        childId: row.child_id,
        childName: row.child_name,
        guardianDisplayName: row.guardian_display_name,
        accessLevel: row.access_level,
        status: row.status,
        expiresAt: toIsoUtc(row.expires_at),
        createdAt: toIsoUtc(row.created_at),
      })),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * Authenticated guardian redeems an invite code.
 * Links the guardian to the child as active (view or co_parent).
 */
guardianInvitesRouter.post(
  '/redeem',
  requireAuth,
  rateLimit,
  async (req: AuthedRequest, res, next) => {
    try {
      const guardianId = req.auth?.userId;
      if (!guardianId) {
        res.status(403).json({ error: 'user_profile_required' });
        return;
      }

      const body = z
        .object({
          code: z.string().min(4).max(16),
          name: z.string().min(1).max(120).optional(),
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
          `UPDATE guardian_invites
           SET status = 'expired'
           WHERE code = $1 AND status = 'pending' AND expires_at <= now()`,
          [code],
        );

        const invite = await client.query<{
          id: string;
          parent_id: string;
          child_id: string;
          access_level: GuardianAccessLevel;
          guardian_display_name: string | null;
        }>(
          `SELECT id, parent_id, child_id, access_level, guardian_display_name
           FROM guardian_invites
           WHERE code = $1 AND status = 'pending' AND expires_at > now()
           FOR UPDATE`,
          [code],
        );
        if (invite.rowCount === 0) {
          await client.query('ROLLBACK');
          res.status(404).json({ error: 'invite_not_found_or_used' });
          return;
        }

        const inviteRow = invite.rows[0];

        if (body.name) {
          await client.query(
            `UPDATE users SET name = COALESCE(NULLIF($2, ''), name), updated_at = now()
             WHERE id = $1`,
            [guardianId, body.name.trim()],
          );
        }

        await client.query(
          `INSERT INTO user_roles (user_id, role)
           VALUES ($1, 'guardian')
           ON CONFLICT DO NOTHING`,
          [guardianId],
        );
        await client.query(
          `INSERT INTO guardian_profiles (user_id, status)
           VALUES ($1, 'active')
           ON CONFLICT (user_id) DO UPDATE SET status = 'active'`,
          [guardianId],
        );

        const link = await client.query<{
          child_id: string;
          guardian_id: string;
          status: string;
          access_level: GuardianAccessLevel;
        }>(
          `INSERT INTO child_approved_guardians
             (child_id, guardian_id, approved_by_parent_id, status, access_level)
           VALUES ($1, $2, $3, 'active', $4::guardian_access_level)
           ON CONFLICT (child_id, guardian_id) DO UPDATE
             SET status = 'active',
                 approved_by_parent_id = EXCLUDED.approved_by_parent_id,
                 access_level = EXCLUDED.access_level,
                 updated_at = now()
           RETURNING child_id, guardian_id, status, access_level`,
          [
            inviteRow.child_id,
            guardianId,
            inviteRow.parent_id,
            inviteRow.access_level,
          ],
        );

        await client.query(
          `UPDATE guardian_invites
           SET status = 'redeemed',
               redeemed_by_guardian_id = $2,
               redeemed_at = now()
           WHERE id = $1`,
          [inviteRow.id, guardianId],
        );

        await client.query(
          `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
           VALUES ($1, $2, 'guardian_invite.redeemed', $3::jsonb)`,
          [
            guardianId,
            inviteRow.child_id,
            JSON.stringify({
              inviteId: inviteRow.id,
              parentId: inviteRow.parent_id,
              code,
              accessLevel: inviteRow.access_level,
            }),
          ],
        );

        await client.query('COMMIT');

        const childName = await pool.query<{ name: string }>(
          `SELECT name FROM users WHERE id = $1`,
          [inviteRow.child_id],
        );

        res.status(201).json({
          childId: link.rows[0].child_id,
          guardianId: link.rows[0].guardian_id,
          status: link.rows[0].status,
          accessLevel: link.rows[0].access_level,
          childName: childName.rows[0]?.name ?? null,
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
  },
);

/** Parent revokes a pending guardian invite code. */
guardianInvitesRouter.post(
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

      const owned = await pool.query<{ child_id: string }>(
        `SELECT child_id FROM guardian_invites
         WHERE id = $1 AND parent_id = $2 AND status = 'pending'`,
        [inviteId, parentId],
      );
      if (owned.rowCount === 0) {
        // Co-parent may have created via canManage — also allow revoke if they manage the child.
        const any = await pool.query<{ id: string; child_id: string; parent_id: string }>(
          `SELECT id, child_id, parent_id FROM guardian_invites
           WHERE id = $1 AND status = 'pending'`,
          [inviteId],
        );
        if (any.rowCount === 0) {
          res.status(404).json({ error: 'invite_not_found' });
          return;
        }
        if (!(await canManageChildFeatures(parentId, any.rows[0].child_id))) {
          res.status(404).json({ error: 'invite_not_found' });
          return;
        }
      }

      const result = await pool.query(
        `UPDATE guardian_invites
         SET status = 'revoked'
         WHERE id = $1 AND status = 'pending'
         RETURNING id, code, status, child_id, access_level`,
        [inviteId],
      );
      if (result.rowCount === 0) {
        res.status(404).json({ error: 'invite_not_found' });
        return;
      }
      res.json({
        ...result.rows[0],
        accessLevel: result.rows[0].access_level,
      });
    } catch (error) {
      next(error);
    }
  },
);
