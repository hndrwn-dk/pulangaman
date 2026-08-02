import { randomBytes } from 'node:crypto';
import { Router } from 'express';
import type { PoolClient } from 'pg';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import {
  hasActiveGuardianLinks,
  isParentOfChild,
  listPrimaryChildren,
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

async function insertInviteRow(
  client: PoolClient,
  input: {
    parentId: string;
    childId: string | null;
    code: string;
    guardianDisplayName: string | null;
    accessLevel: GuardianAccessLevel;
    expiresAt: Date;
  },
): Promise<{
  id: string;
  code: string;
  expires_at: Date;
  created_at: Date;
  access_level: GuardianAccessLevel;
}> {
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
      input.parentId,
      input.childId,
      input.code,
      input.guardianDisplayName,
      input.accessLevel,
      input.expiresAt.toISOString(),
    ],
  );
  return result.rows[0];
}

/** Primary parent creates a short invite code for a guardian. */
guardianInvitesRouter.post('/', requireAuth, rateLimit, async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid().optional(),
        allChildren: z.boolean().optional(),
        accessLevel: accessLevelSchema.default('view'),
        guardianDisplayName: z.string().min(1).max(120).optional(),
      })
      .superRefine((value, ctx) => {
        const hasChild = typeof value.childId === 'string';
        const all = value.allChildren === true;
        if (all === hasChild) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: 'Provide either childId or allChildren: true',
            path: ['childId'],
          });
        }
      })
      .parse(req.body ?? {});

    const allChildren = body.allChildren === true;
    let childId: string | null = null;
    let childName: string | null = null;

    if (allChildren) {
      const primary = await listPrimaryChildren(parentId);
      if (primary.length === 0) {
        res.status(404).json({ error: 'child_not_found' });
        return;
      }
    } else {
      childId = body.childId!;
      // Invite create is primary-parent only (not co_parent manage).
      if (!(await isParentOfChild(parentId, childId))) {
        res.status(404).json({ error: 'child_not_found' });
        return;
      }
      const child = await pool.query<{ name: string }>(
        `SELECT name FROM users WHERE id = $1`,
        [childId],
      );
      childName = child.rows[0]?.name ?? null;
    }

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

      if (allChildren) {
        // At most one pending family-wide code for this inviter.
        await client.query(
          `UPDATE guardian_invites
           SET status = 'revoked'
           WHERE parent_id = $1
             AND child_id IS NULL
             AND status = 'pending'`,
          [parentId],
        );
      } else {
        // At most one pending code per child for this parent.
        await client.query(
          `UPDATE guardian_invites
           SET status = 'revoked'
           WHERE parent_id = $1
             AND child_id = $2
             AND status = 'pending'`,
          [parentId, childId],
        );
      }

      let code = generateInviteCode();
      for (let attempt = 0; attempt < 5; attempt += 1) {
        const expiresAt = new Date(Date.now() + INVITE_TTL_HOURS * 3_600_000);
        try {
          const row = await insertInviteRow(client, {
            parentId,
            childId,
            code,
            guardianDisplayName: body.guardianDisplayName ?? null,
            accessLevel: body.accessLevel,
            expiresAt,
          });
          await client.query(
            `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
             VALUES ($1, $2, 'guardian_invite.created', $3::jsonb)`,
            [
              parentId,
              childId,
              JSON.stringify({
                inviteId: row.id,
                code,
                accessLevel: body.accessLevel,
                allChildren,
              }),
            ],
          );
          await client.query('COMMIT');
          res.status(201).json({
            id: row.id,
            code: row.code,
            expiresAt: toIsoUtc(row.expires_at),
            createdAt: toIsoUtc(row.created_at),
            childId,
            childName,
            allChildren,
            scope: allChildren ? 'all' : 'child',
            accessLevel: row.access_level,
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
      child_id: string | null;
      child_name: string | null;
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
       LEFT JOIN users u ON u.id = gi.child_id
       WHERE gi.parent_id = $1
         AND gi.status = 'pending'
         AND gi.expires_at > now()
         AND gi.created_at > now() - ($2::int * interval '1 hour')
       ORDER BY gi.created_at DESC
       LIMIT 20`,
      [parentId, INVITE_TTL_HOURS],
    );

    res.json({
      invites: result.rows.map((row) => {
        const allChildren = row.child_id == null;
        return {
          id: row.id,
          code: row.code,
          childId: row.child_id,
          childName: row.child_name,
          allChildren,
          scope: allChildren ? 'all' : 'child',
          guardianDisplayName: row.guardian_display_name,
          accessLevel: row.access_level,
          status: row.status,
          expiresAt: toIsoUtc(row.expires_at),
          createdAt: toIsoUtc(row.created_at),
        };
      }),
    });
  } catch (error) {
    next(error);
  }
});

/**
 * Authenticated guardian redeems an invite code.
 * Links the guardian to the child (or all managed children) as active.
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

      // After first link, redeem is closed — only primary admin adds more children.
      if (await hasActiveGuardianLinks(guardianId)) {
        res.status(403).json({ error: 'already_linked' });
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
          child_id: string | null;
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

        let targetChildIds: string[];
        if (inviteRow.child_id) {
          targetChildIds = [inviteRow.child_id];
        } else {
          const primary = await listPrimaryChildren(inviteRow.parent_id);
          targetChildIds = primary.map((c) => c.id);
        }

        if (targetChildIds.length === 0) {
          await client.query('ROLLBACK');
          res.status(404).json({ error: 'invite_no_children' });
          return;
        }

        const linked: Array<{
          childId: string;
          guardianId: string;
          status: string;
          accessLevel: GuardianAccessLevel;
        }> = [];

        for (const targetChildId of targetChildIds) {
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
              targetChildId,
              guardianId,
              inviteRow.parent_id,
              inviteRow.access_level,
            ],
          );

          await client.query(
            `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
             VALUES ($1, $2, 'guardian_invite.redeemed', $3::jsonb)`,
            [
              guardianId,
              targetChildId,
              JSON.stringify({
                inviteId: inviteRow.id,
                parentId: inviteRow.parent_id,
                code,
                accessLevel: inviteRow.access_level,
                allChildren: inviteRow.child_id == null,
              }),
            ],
          );

          linked.push({
            childId: link.rows[0].child_id,
            guardianId: link.rows[0].guardian_id,
            status: link.rows[0].status,
            accessLevel: link.rows[0].access_level,
          });
        }

        await client.query(
          `UPDATE guardian_invites
           SET status = 'redeemed',
               redeemed_by_guardian_id = $2,
               redeemed_at = now()
           WHERE id = $1`,
          [inviteRow.id, guardianId],
        );

        await client.query('COMMIT');

        const names = await pool.query<{ id: string; name: string }>(
          `SELECT id, name FROM users WHERE id = ANY($1::uuid[])`,
          [targetChildIds],
        );
        const nameById = new Map(names.rows.map((r) => [r.id, r.name]));
        const childNames = targetChildIds.map(
          (id) => nameById.get(id) ?? id,
        );

        res.status(201).json({
          childId: linked[0]!.childId,
          childIds: linked.map((l) => l.childId),
          guardianId: linked[0]!.guardianId,
          status: linked[0]!.status,
          accessLevel: linked[0]!.accessLevel,
          childName: childNames.join(', '),
          childNames,
          allChildren: inviteRow.child_id == null,
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

/** Primary parent revokes a pending guardian invite code. */
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

      // Only the invite creator (primary) may revoke — co-parents cannot create.
      const owned = await pool.query<{ child_id: string | null }>(
        `SELECT child_id FROM guardian_invites
         WHERE id = $1 AND parent_id = $2 AND status = 'pending'`,
        [inviteId, parentId],
      );
      if (owned.rowCount === 0) {
        res.status(404).json({ error: 'invite_not_found' });
        return;
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
        allChildren: result.rows[0].child_id == null,
        accessLevel: result.rows[0].access_level,
      });
    } catch (error) {
      next(error);
    }
  },
);
