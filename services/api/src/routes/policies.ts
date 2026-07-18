import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { isParentOfChild } from '../middleware/roles.js';
import { sendFcmToUser } from '../services/fcm.js';
import { config } from '../config.js';

export const policiesRouter = Router();
policiesRouter.use(requireAuth, rateLimit);

const mandatoryAllowlist = [
  'com.tursinalabs.pulangaman',
  'com.android.dialer',
  'com.google.android.dialer',
  'com.android.messaging',
  'com.google.android.apps.messaging',
];

policiesRouter.post('/device', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    const body = z
      .object({
        installationId: z.string().min(8).max(200),
        deviceName: z.string().max(120).optional(),
        appVersion: z.string().max(40).optional(),
        usageAccessGranted: z.boolean().default(false),
        accessibilityEnabled: z.boolean().default(false),
      })
      .parse(req.body);
    if (!childId) {
      res.status(403).json({ error: 'child_profile_required' });
      return;
    }
    const childRole = await pool.query(
      `SELECT 1 FROM user_roles WHERE user_id = $1 AND role = 'child'`,
      [childId],
    );
    if (childRole.rowCount === 0) {
      res.status(403).json({ error: 'child_role_required' });
      return;
    }
    const result = await pool.query<{ id: string }>(
      `INSERT INTO child_devices
         (child_id, installation_id, device_name, app_version,
          usage_access_granted, accessibility_enabled)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (installation_id) DO UPDATE SET
         child_id = EXCLUDED.child_id,
         device_name = EXCLUDED.device_name,
         app_version = EXCLUDED.app_version,
         usage_access_granted = EXCLUDED.usage_access_granted,
         accessibility_enabled = EXCLUDED.accessibility_enabled,
         last_seen_at = now()
       RETURNING id`,
      [
        childId,
        body.installationId,
        body.deviceName ?? null,
        body.appVersion ?? null,
        body.usageAccessGranted,
        body.accessibilityEnabled,
      ],
    );
    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    next(error);
  }
});

policiesRouter.put('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    const body = z
      .object({
        enabled: z.boolean().default(true),
        dailyLimitMinutes: z.number().int().min(15).max(1440).default(120),
        blockedPackages: z.array(z.string().min(1).max(200)).max(200).default([]),
        schedules: z
          .array(
            z.object({
              days: z.array(z.number().int().min(1).max(7)).min(1),
              start: z.string().regex(/^\d{2}:\d{2}$/),
              end: z.string().regex(/^\d{2}:\d{2}$/),
            }),
          )
          .max(20)
          .default([]),
        emergencyAllowlist: z.array(z.string().min(1).max(200)).max(50).default([]),
      })
      .parse(req.body);
    if (!parentId || !(await isParentOfChild(parentId, childId))) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }
    const versionResult = await pool.query<{ version: number }>(
      `SELECT COALESCE(MAX(version), 0) + 1 AS version
       FROM device_policies WHERE child_id = $1`,
      [childId],
    );
    const version = Number(versionResult.rows[0].version);
    const allowlist = [...new Set([...mandatoryAllowlist, ...body.emergencyAllowlist])];
    const policy = await pool.query<{ id: string }>(
      `INSERT INTO device_policies
         (child_id, created_by_parent_id, version, enabled, daily_limit_minutes,
          blocked_packages, schedules, emergency_allowlist)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb)
       RETURNING id`,
      [
        childId,
        parentId,
        version,
        body.enabled && !config.KILL_SWITCH_POLICY_ENFORCE,
        body.dailyLimitMinutes,
        JSON.stringify(body.blockedPackages),
        JSON.stringify(body.schedules),
        JSON.stringify(allowlist),
      ],
    );
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'policy.published', $3::jsonb)`,
      [parentId, childId, JSON.stringify({ policyId: policy.rows[0].id, version })],
    );
    await sendFcmToUser(
      childId,
      { title: 'Aturan waktu layar diperbarui', body: 'Buka PulangAman untuk sinkronisasi' },
      { type: 'policy_sync', version: String(version) },
    );
    res.status(201).json({ id: policy.rows[0].id, version, emergencyAllowlist: allowlist });
  } catch (error) {
    next(error);
  }
});

policiesRouter.get('/current/me', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    if (!childId) {
      res.status(403).json({ error: 'child_profile_required' });
      return;
    }
    const result = await pool.query(
      `SELECT id, version, enabled, daily_limit_minutes, blocked_packages,
              schedules, emergency_allowlist, created_at
       FROM device_policies
       WHERE child_id = $1
       ORDER BY version DESC
       LIMIT 1`,
      [childId],
    );
    res.json({
      policy: result.rows[0] ?? null,
      enforcementDisabled: config.KILL_SWITCH_POLICY_ENFORCE,
    });
  } catch (error) {
    next(error);
  }
});

policiesRouter.get('/:childId', async (req: AuthedRequest, res, next) => {
  try {
    const parentId = req.auth?.userId;
    const childId = z.string().uuid().parse(req.params.childId);
    if (!parentId || !(await isParentOfChild(parentId, childId))) {
      res.status(403).json({ error: 'parent_access_required' });
      return;
    }
    const result = await pool.query(
      `SELECT id, version, enabled, daily_limit_minutes, blocked_packages,
              schedules, emergency_allowlist, created_at
       FROM device_policies
       WHERE child_id = $1
       ORDER BY version DESC
       LIMIT 1`,
      [childId],
    );
    res.json({ policy: result.rows[0] ?? null });
  } catch (error) {
    next(error);
  }
});

policiesRouter.post('/ack', async (req: AuthedRequest, res, next) => {
  try {
    const childId = req.auth?.userId;
    const body = z
      .object({
        installationId: z.string().min(8).max(200),
        policyId: z.string().uuid(),
        version: z.number().int().positive(),
      })
      .parse(req.body);
    if (!childId) {
      res.status(403).json({ error: 'child_profile_required' });
      return;
    }
    const device = await pool.query<{ id: string }>(
      `SELECT id FROM child_devices
       WHERE child_id = $1 AND installation_id = $2`,
      [childId, body.installationId],
    );
    if (device.rowCount === 0) {
      res.status(404).json({ error: 'device_not_found' });
      return;
    }
    await pool.query(
      `INSERT INTO device_policy_acks (device_id, policy_id, version)
       VALUES ($1, $2, $3)
       ON CONFLICT (device_id, policy_id) DO UPDATE
         SET version = EXCLUDED.version, acked_at = now()`,
      [device.rows[0].id, body.policyId, body.version],
    );
    await pool.query(
      `UPDATE child_devices
       SET last_policy_version = GREATEST(last_policy_version, $2), last_seen_at = now()
       WHERE id = $1`,
      [device.rows[0].id, body.version],
    );
    res.json({ acknowledged: true });
  } catch (error) {
    next(error);
  }
});
