import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { config } from '../config.js';
import { guardianPresenceKey, getRedis } from '../redis/client.js';
import {
  canViewChild,
  getActiveGuardianAccess,
  isParentOfChild,
  listViewableChildren,
  type GuardianAccessLevel,
} from '../middleware/roles.js';
import { guardianLeaveAuditAction } from './guardianLeaveLogic.js';

export const guardiansRouter = Router();

guardiansRouter.use(requireAuth, rateLimit);

const accessLevelSchema = z.enum(['view', 'co_parent']);

const inviteSchema = z.object({
  childId: z.string().uuid(),
  guardianPhone: z.string().min(8).max(20),
  guardianName: z.string().min(1).max(120),
  accessLevel: accessLevelSchema.default('view'),
});

const presenceSchema = z.object({
  status: z.enum(['ONLINE', 'BUSY', 'OFFLINE']),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
});

const shareLocationSchema = z.object({
  alertId: z.string().uuid(),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

guardiansRouter.post('/invite', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = inviteSchema.parse(req.body);
    // Guardian invite is primary-parent only (not co_parent manage).
    if (!(await isParentOfChild(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      let guardianId: string;
      const existing = await client.query<{ id: string }>(
        `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
        [body.guardianPhone],
      );

      if (existing.rowCount && existing.rows[0]) {
        guardianId = existing.rows[0].id;
      } else {
        const created = await client.query<{ id: string }>(
          `INSERT INTO users (firebase_uid, phone, name)
           VALUES ($1, $2, $3)
           RETURNING id`,
          [`pending:${body.guardianPhone}`, body.guardianPhone, body.guardianName],
        );
        guardianId = created.rows[0].id;
      }

      await client.query(
        `INSERT INTO user_roles (user_id, role)
         VALUES ($1, 'guardian')
         ON CONFLICT DO NOTHING`,
        [guardianId],
      );
      await client.query(
        `INSERT INTO guardian_profiles (user_id)
         VALUES ($1)
         ON CONFLICT DO NOTHING`,
        [guardianId],
      );
      await client.query(
        `INSERT INTO child_approved_guardians
           (child_id, guardian_id, approved_by_parent_id, status, access_level)
         VALUES ($1, $2, $3, 'invited', $4::guardian_access_level)
         ON CONFLICT (child_id, guardian_id) DO UPDATE
           SET status = 'invited',
               approved_by_parent_id = EXCLUDED.approved_by_parent_id,
               access_level = EXCLUDED.access_level,
               updated_at = now()`,
        [body.childId, guardianId, parentId, body.accessLevel],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'guardian.invited', $3::jsonb)`,
        [
          parentId,
          body.childId,
          JSON.stringify({ guardianId, accessLevel: body.accessLevel }),
        ],
      );

      await client.query('COMMIT');
      res.status(201).json({
        guardianId,
        status: 'invited',
        accessLevel: body.accessLevel,
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

guardiansRouter.post('/accept', async (req: AuthedRequest, res, next) => {
  try {
    const firebaseUid = req.auth!.firebaseUid;
    const phone = req.auth?.phone;
    const body = z
      .object({
        childId: z.string().uuid(),
        name: z.string().min(1).max(120).optional(),
      })
      .parse(req.body);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      let guardianId = req.auth?.userId;

      // Bind pending invite user (pending:{phone}) to the real Firebase identity.
      if (!guardianId && phone) {
        const pending = await client.query<{ id: string }>(
          `SELECT id FROM users WHERE phone = $1 AND firebase_uid = $2 LIMIT 1`,
          [phone, `pending:${phone}`],
        );
        if (pending.rowCount && pending.rows[0]) {
          guardianId = pending.rows[0].id;
          await client.query(
            `UPDATE users
             SET firebase_uid = $2,
                 name = COALESCE($3, name),
                 updated_at = now()
             WHERE id = $1`,
            [guardianId, firebaseUid, body.name ?? null],
          );
        }
      }

      if (!guardianId) {
        await client.query('ROLLBACK');
        res.status(403).json({ error: 'user_profile_required' });
        return;
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

      const result = await client.query<{
        child_id: string;
        guardian_id: string;
        status: string;
        access_level: GuardianAccessLevel;
      }>(
        `UPDATE child_approved_guardians
         SET status = 'active', updated_at = now()
         WHERE child_id = $1 AND guardian_id = $2 AND status = 'invited'
         RETURNING child_id, guardian_id, status, access_level`,
        [body.childId, guardianId],
      );
      if (result.rowCount === 0) {
        await client.query('ROLLBACK');
        res.status(404).json({ error: 'invite_not_found' });
        return;
      }

      await client.query(
        `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
         VALUES ($1, $2, 'guardian.accepted', $3::jsonb)`,
        [
          guardianId,
          body.childId,
          JSON.stringify({
            guardianId,
            accessLevel: result.rows[0].access_level,
          }),
        ],
      );

      await client.query('COMMIT');
      res.json({
        ...result.rows[0],
        accessLevel: result.rows[0].access_level,
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

guardiansRouter.post('/revoke', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const body = z
      .object({
        childId: z.string().uuid(),
        guardianId: z.string().uuid(),
      })
      .parse(req.body);

    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // Revoke is primary-parent only (not co_parent manage).
    if (!(await isParentOfChild(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    if (body.guardianId === parentId) {
      res.status(400).json({ error: 'cannot_revoke_self' });
      return;
    }

    const result = await pool.query(
      `UPDATE child_approved_guardians
       SET status = 'revoked', updated_at = now()
       WHERE child_id = $1 AND guardian_id = $2 AND status IN ('invited', 'active')
       RETURNING child_id, guardian_id, status, access_level`,
      [body.childId, body.guardianId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'guardian_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'guardian.revoked', $3::jsonb)`,
      [parentId, body.childId, JSON.stringify({ guardianId: body.guardianId })],
    );

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

guardiansRouter.patch('/access-level', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const body = z
      .object({
        childId: z.string().uuid(),
        guardianId: z.string().uuid(),
        accessLevel: accessLevelSchema,
      })
      .parse(req.body);

    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    // Promote / demote is primary-parent only (not co_parent manage).
    if (!(await isParentOfChild(parentId, body.childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    if (body.guardianId === parentId) {
      res.status(400).json({ error: 'cannot_change_own_access' });
      return;
    }

    const result = await pool.query<{
      child_id: string;
      guardian_id: string;
      status: string;
      access_level: GuardianAccessLevel;
    }>(
      `UPDATE child_approved_guardians
       SET access_level = $3::guardian_access_level, updated_at = now()
       WHERE child_id = $1
         AND guardian_id = $2
         AND status IN ('invited', 'active')
       RETURNING child_id, guardian_id, status, access_level`,
      [body.childId, body.guardianId, body.accessLevel],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'guardian_not_found' });
      return;
    }

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'guardian.access_level_changed', $3::jsonb)`,
      [
        parentId,
        body.childId,
        JSON.stringify({
          guardianId: body.guardianId,
          accessLevel: body.accessLevel,
        }),
      ],
    );

    res.json({
      ...result.rows[0],
      accessLevel: result.rows[0].access_level,
    });
  } catch (error) {
    next(error);
  }
});

guardiansRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.query.childId);
    if (!parentId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    if (!(await canViewChild(parentId, childId))) {
      res.status(404).json({ error: 'child_not_found' });
      return;
    }

    const result = await pool.query(
      `SELECT cag.guardian_id, cag.status, cag.access_level, u.name, u.phone,
              gp.status AS guardian_status
       FROM child_approved_guardians cag
       JOIN users u ON u.id = cag.guardian_id
       LEFT JOIN guardian_profiles gp ON gp.user_id = cag.guardian_id
       WHERE cag.child_id = $1
       ORDER BY cag.created_at`,
      [childId],
    );

    const primary = await pool.query<{ id: string; name: string }>(
      `SELECT u.id, u.name
       FROM parent_children pc
       JOIN users u ON u.id = pc.parent_id
       WHERE pc.child_id = $1
       LIMIT 1`,
      [childId],
    );
    const primaryRow = primary.rows[0];

    res.json({
      guardians: result.rows.map((row) => ({
        ...row,
        accessLevel: row.access_level as GuardianAccessLevel,
      })),
      primaryParent: primaryRow
        ? { id: primaryRow.id, name: primaryRow.name }
        : null,
    });
  } catch (error) {
    next(error);
  }
});

/** Children this user can view as primary parent or any active guardian. */
guardiansRouter.get('/children', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const children = await listViewableChildren(userId);
    res.json({
      children: children.map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        grade: c.grade,
        commute_status: c.commute_status,
        last_seen_at: c.last_seen_at,
        access: c.access,
        accessLevel: c.accessLevel,
      })),
    });
  } catch (error) {
    next(error);
  }
});

guardiansRouter.get('/invites', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `SELECT cag.child_id, cag.status, cag.access_level, u.name AS child_name,
              p.name AS parent_name
       FROM child_approved_guardians cag
       JOIN users u ON u.id = cag.child_id
       JOIN users p ON p.id = cag.approved_by_parent_id
       WHERE cag.guardian_id = $1 AND cag.status = 'invited'
       ORDER BY cag.created_at DESC`,
      [guardianId],
    );
    res.json({
      invites: result.rows.map((row) => ({
        ...row,
        accessLevel: row.access_level as GuardianAccessLevel,
      })),
    });
  } catch (error) {
    next(error);
  }
});

guardiansRouter.post('/presence', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = presenceSchema.parse(req.body);
    const redis = getRedis();
    if (redis.status !== 'ready') {
      await redis.connect();
    }

    await redis.set(
      guardianPresenceKey(guardianId),
      JSON.stringify({
        status: body.status,
        lat: body.lat ?? null,
        lng: body.lng ?? null,
        updatedAt: new Date().toISOString(),
      }),
      'EX',
      config.LOCATION_TTL_SECONDS,
    );

    if (body.lat !== undefined && body.lng !== undefined) {
      await pool.query(
        `UPDATE guardian_profiles
         SET home_location = ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography
         WHERE user_id = $1`,
        [guardianId, body.lng, body.lat],
      );
    }

    res.json({ ok: true, status: body.status });
  } catch (error) {
    next(error);
  }
});

// Jalur 1 — immediate, self-service.
guardiansRouter.post('/leave', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    const body = z.object({ childId: z.string().uuid() }).parse(req.body);
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const result = await pool.query(
      `UPDATE child_approved_guardians
       SET status = 'revoked', updated_at = now()
       WHERE child_id = $1 AND guardian_id = $2 AND status IN ('invited', 'active')
       RETURNING child_id, guardian_id, status`,
      [body.childId, guardianId],
    );
    if (result.rowCount === 0) {
      res.status(404).json({ error: 'guardian_link_not_found' });
      return;
    }
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, $3, '{}'::jsonb)`,
      [guardianId, body.childId, guardianLeaveAuditAction('leave')],
    );

    const parent = await pool.query<{ parent_id: string }>(
      `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
      [body.childId],
    );
    if (parent.rowCount) {
      const { sendFcmToUser } = await import('../services/fcm.js');
      await sendFcmToUser(
        parent.rows[0].parent_id,
        { title: 'PulangAman', body: 'Seorang wali baru saja berhenti mengakses akun anak Anda.' },
        { type: 'guardian_left', childId: body.childId, route: 'child_detail' },
      ).catch((err) => console.error('guardian_left_notify_failed', { err }));
    }

    res.json(result.rows[0]);
  } catch (error) {
    next(error);
  }
});

// Jalur 2 — request only, does NOT change status. Access stays active
// until the parent acts via the EXISTING /guardians/revoke. Don't add a
// new child_approved_guardians status for this — it would ripple into
// getActiveGuardianAccess/canViewChild and everywhere else checking
// status = 'active'.
guardiansRouter.post('/leave-request', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    const body = z.object({ childId: z.string().uuid() }).parse(req.body);
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    const access = await getActiveGuardianAccess(guardianId, body.childId);
    if (!access) {
      res.status(404).json({ error: 'guardian_link_not_found' });
      return;
    }

    const [guardian, parent] = await Promise.all([
      pool.query<{ name: string }>(`SELECT name FROM users WHERE id = $1`, [guardianId]),
      pool.query<{ parent_id: string }>(
        `SELECT parent_id FROM parent_children WHERE child_id = $1 LIMIT 1`,
        [body.childId],
      ),
    ]);
    if (parent.rowCount === 0) {
      res.status(400).json({ error: 'parent_link_missing' });
      return;
    }

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, $3, '{}'::jsonb)`,
      [guardianId, body.childId, guardianLeaveAuditAction('leave-request')],
    );

    const guardianName = guardian.rows[0]?.name ?? 'Seorang wali';
    const { sendFcmToUser } = await import('../services/fcm.js');
    await sendFcmToUser(
      parent.rows[0].parent_id,
      {
        title: 'PulangAman — Permintaan dari wali',
        body: `${guardianName} minta akses ke akun anak Anda dicabut. Ketuk untuk tinjau.`,
      },
      { type: 'guardian_leave_requested', childId: body.childId, route: 'child_detail' },
    ).catch((err) => console.error('guardian_leave_request_notify_failed', { err }));

    res.status(202).json({ requested: true });
  } catch (error) {
    next(error);
  }
});

guardiansRouter.post('/share-location', async (req: AuthedRequest, res, next) => {
  try {
    const guardianId = req.auth?.userId;
    if (!guardianId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }
    if (config.KILL_SWITCH_LOCATION_SHARE) {
      res.status(503).json({ error: 'location_share_disabled' });
      return;
    }

    const body = shareLocationSchema.parse(req.body);
    const alert = await pool.query<{ parent_id: string; child_id: string }>(
      `SELECT pa.parent_id, pa.child_id
       FROM panic_alerts pa
       JOIN panic_alert_recipients par ON par.alert_id = pa.id
       WHERE pa.id = $1
         AND par.user_id = $2
         AND pa.status IN ('active', 'parent_responded', 'guardian_notified')`,
      [body.alertId, guardianId],
    );
    if (alert.rowCount === 0) {
      res.status(404).json({ error: 'alert_not_found' });
      return;
    }

    const { parent_id: parentId, child_id: childId } = alert.rows[0];
    const { sendFcmToUser } = await import('../services/fcm.js');
    const { broadcastToRoom, childRoom } = await import('../ws/server.js');

    broadcastToRoom(childRoom(childId), 'guardian:location_share', {
      alertId: body.alertId,
      guardianId,
      lat: body.lat,
      lng: body.lng,
    });

    await sendFcmToUser(
      parentId,
      {
        title: 'PulangAman — Lokasi wali',
        body: 'Wali terpercaya membagikan lokasi saat panik.',
      },
      {
        type: 'guardian_location',
        alertId: body.alertId,
        guardianId,
      },
    );

    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'guardian.share_location', $3::jsonb)`,
      [guardianId, childId, JSON.stringify({ alertId: body.alertId })],
    );

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});
