import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db/pool.js';
import { requireAuth, type AuthedRequest } from '../middleware/auth.js';
import { rateLimit } from '../middleware/rateLimit.js';
import { sendSms } from '../services/sms.js';

export const schoolsRouter = Router();

schoolsRouter.use(requireAuth, rateLimit);

async function assertSchoolAdmin(userId: string, schoolId: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM school_admins WHERE user_id = $1 AND school_id = $2`,
    [userId, schoolId],
  );
  return (result.rowCount ?? 0) > 0;
}

const createSchoolSchema = z.object({
  name: z.string().min(1).max(200),
  address: z.string().max(400).optional(),
  panicContactPhone: z.string().min(8).max(20).optional(),
  panicContactName: z.string().max(120).optional(),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
  radiusM: z.number().int().min(50).max(2000).default(200),
});

schoolsRouter.post('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const body = createSchoolSchema.parse(req.body);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const school = await client.query<{ id: string }>(
        `INSERT INTO schools (
           name, address, panic_contact_phone, panic_contact_name, center, radius_m
         ) VALUES (
           $1, $2, $3, $4,
           CASE WHEN $5::float8 IS NULL THEN NULL
                ELSE ST_SetSRID(ST_MakePoint($6, $5), 4326)::geography END,
           $7
         )
         RETURNING id`,
        [
          body.name,
          body.address ?? null,
          body.panicContactPhone ?? null,
          body.panicContactName ?? null,
          body.lat ?? null,
          body.lng ?? null,
          body.radiusM,
        ],
      );
      const schoolId = school.rows[0].id;

      await client.query(
        `INSERT INTO user_roles (user_id, role)
         VALUES ($1, 'school_admin')
         ON CONFLICT DO NOTHING`,
        [userId],
      );
      await client.query(
        `INSERT INTO school_admins (school_id, user_id) VALUES ($1, $2)`,
        [schoolId, userId],
      );
      await client.query(
        `INSERT INTO audit_events (actor_id, action, payload)
         VALUES ($1, 'school.created', $2::jsonb)`,
        [userId, JSON.stringify({ schoolId })],
      );
      await client.query('COMMIT');
      res.status(201).json({ id: schoolId, name: body.name });
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

schoolsRouter.get('/', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      res.status(403).json({ error: 'user_profile_required' });
      return;
    }

    const result = await pool.query(
      `SELECT s.id, s.name, s.address, s.panic_contact_phone, s.panic_contact_name,
              s.radius_m,
              ST_Y(s.center::geometry) AS lat,
              ST_X(s.center::geometry) AS lng
       FROM schools s
       JOIN school_admins sa ON sa.school_id = s.id
       WHERE sa.user_id = $1
       ORDER BY s.name`,
      [userId],
    );
    res.json({ schools: result.rows });
  } catch (error) {
    next(error);
  }
});

schoolsRouter.get('/:id/roster', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const schoolId = String(req.params.id);
    if (!userId || !(await assertSchoolAdmin(userId, schoolId))) {
      res.status(403).json({ error: 'school_admin_required' });
      return;
    }

    const result = await pool.query(
      `SELECT sr.child_id, u.name, u.phone, sr.grade, cp.commute_status, cp.last_seen_at,
              CASE
                WHEN s.center IS NULL OR cp.last_seen_at IS NULL THEN NULL
                WHEN EXISTS (
                  SELECT 1 FROM location_history lh
                  WHERE lh.child_id = sr.child_id
                    AND lh.recorded_at > now() - interval '30 minutes'
                    AND ST_DWithin(lh.location, s.center, s.radius_m)
                ) THEN true
                ELSE false
              END AS inside_school_geofence
       FROM school_roster sr
       JOIN users u ON u.id = sr.child_id
       JOIN schools s ON s.id = sr.school_id
       LEFT JOIN child_profiles cp ON cp.user_id = sr.child_id
       WHERE sr.school_id = $1
       ORDER BY u.name`,
      [schoolId],
    );
    res.json({ roster: result.rows });
  } catch (error) {
    next(error);
  }
});

schoolsRouter.post('/:id/roster', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const schoolId = String(req.params.id);
    if (!userId || !(await assertSchoolAdmin(userId, schoolId))) {
      res.status(403).json({ error: 'school_admin_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid(),
        grade: z.number().int().min(1).max(12).optional(),
      })
      .parse(req.body);

    await pool.query(
      `INSERT INTO school_roster (school_id, child_id, grade)
       VALUES ($1, $2, $3)
       ON CONFLICT (school_id, child_id) DO UPDATE SET grade = EXCLUDED.grade`,
      [schoolId, body.childId, body.grade ?? null],
    );
    await pool.query(
      `UPDATE child_profiles SET school_id = $2 WHERE user_id = $1`,
      [body.childId, schoolId],
    );

    res.status(201).json({ schoolId, childId: body.childId });
  } catch (error) {
    next(error);
  }
});

schoolsRouter.patch('/:id/panic-contact', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const schoolId = String(req.params.id);
    if (!userId || !(await assertSchoolAdmin(userId, schoolId))) {
      res.status(403).json({ error: 'school_admin_required' });
      return;
    }

    const body = z
      .object({
        panicContactPhone: z.string().min(8).max(20),
        panicContactName: z.string().max(120).optional(),
      })
      .parse(req.body);

    await pool.query(
      `UPDATE schools
       SET panic_contact_phone = $2,
           panic_contact_name = $3,
           updated_at = now()
       WHERE id = $1`,
      [schoolId, body.panicContactPhone, body.panicContactName ?? null],
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

/** Notify school panic contact (manual or cascade helper). */
schoolsRouter.post('/:id/notify-panic', async (req: AuthedRequest, res, next) => {
  try {
    const userId = req.auth?.userId;
    const schoolId = String(req.params.id);
    if (!userId || !(await assertSchoolAdmin(userId, schoolId))) {
      res.status(403).json({ error: 'school_admin_required' });
      return;
    }

    const body = z
      .object({
        childId: z.string().uuid().optional(),
        message: z.string().max(400).optional(),
      })
      .parse(req.body);

    const school = await pool.query<{
      panic_contact_phone: string | null;
      name: string;
    }>(`SELECT panic_contact_phone, name FROM schools WHERE id = $1`, [schoolId]);

    const phone = school.rows[0]?.panic_contact_phone;
    if (!phone) {
      res.status(400).json({ error: 'panic_contact_missing' });
      return;
    }

    const message =
      body.message ??
      `PulangAman: peringatan panik terkait sekolah ${school.rows[0].name}. Periksa aplikasi.`;

    await sendSms(phone, message);
    await pool.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'school.panic_notify', $3::jsonb)`,
      [userId, body.childId ?? null, JSON.stringify({ schoolId })],
    );

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});
