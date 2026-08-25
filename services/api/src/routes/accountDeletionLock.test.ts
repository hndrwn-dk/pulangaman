import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { describe, it } from 'node:test';
import dotenv from 'dotenv';
import pg from 'pg';

dotenv.config({
  path: path.join(path.dirname(fileURLToPath(import.meta.url)), '../../.env'),
});

const { Pool } = pg;

function makePool(): pg.Pool | null {
  const url = process.env.DATABASE_URL;
  if (!url) return null;
  const requiresSsl =
    process.env.NODE_ENV === 'production' ||
    /sslmode=require|neon\.tech|render\.com|\.aws\./i.test(url);
  return new Pool({
    connectionString: url,
    ssl: requiresSsl ? { rejectUnauthorized: false } : undefined,
  });
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

describe('account deletion parent_children lock', () => {
  it('blocks a concurrent parent_children INSERT until the deletion transaction finishes', { timeout: 20_000 }, async (t) => {
    const pool = makePool();
    if (!pool) {
      t.skip('DATABASE_URL is not set');
      return;
    }

    try {
      await pool.query('SELECT 1');
    } catch (err) {
      await pool.end().catch(() => undefined);
      const message =
        err instanceof Error && err.message
          ? err.message
          : err && typeof err === 'object' && 'code' in err
            ? String((err as { code?: string }).code)
            : String(err);
      t.skip(`database unavailable (${message})`);
      return;
    }

    const parentId = randomUUID();
    const childId = randomUUID();
    const extraChildId = randomUUID();
    const suffix = parentId.replace(/-/g, '').slice(0, 12);

    const clientA = await pool.connect();
    const clientB = await pool.connect();
    let insertPromise: Promise<unknown> | null = null;
    let insertSettled = false;

    try {
      await pool.query(
        `INSERT INTO users (id, firebase_uid, phone, name)
         VALUES
           ($1, $4, $7, 'Lock Parent'),
           ($2, $5, $8, 'Lock Child'),
           ($3, $6, $9, 'Lock Extra')`,
        [
          parentId,
          childId,
          extraChildId,
          `del-lock-p-${suffix}`,
          `del-lock-c-${suffix}`,
          `del-lock-x-${suffix}`,
          `+62000${suffix.slice(0, 8)}1`,
          `+62000${suffix.slice(0, 8)}2`,
          `+62000${suffix.slice(0, 8)}3`,
        ],
      );
      await pool.query(
        `INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)`,
        [parentId, childId],
      );

      await clientA.query('BEGIN');
      // Same locks as DELETE /api/v1/account in account.ts.
      await clientA.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [parentId]);
      await clientA.query(
        `SELECT u.id, u.name
         FROM parent_children pc
         JOIN users u ON u.id = pc.child_id
         WHERE pc.parent_id = $1
         ORDER BY u.name
         FOR UPDATE OF u`,
        [parentId],
      );

      insertPromise = clientB
        .query(
          `INSERT INTO parent_children (parent_id, child_id) VALUES ($1, $2)`,
          [parentId, extraChildId],
        )
        .finally(() => {
          insertSettled = true;
        });

      const deadline = Date.now() + 4000;
      while (Date.now() < deadline && !insertSettled) {
        const wait = await pool.query<{ wait_event_type: string | null }>(
          `SELECT wait_event_type FROM pg_stat_activity WHERE pid = $1`,
          [clientB.processID],
        );
        if (wait.rows[0]?.wait_event_type === 'Lock') break;
        await delay(50);
      }

      assert.equal(
        insertSettled,
        false,
        'concurrent INSERT must block on the row lock instead of linking a child that would be orphaned',
      );

      await clientA.query('DELETE FROM users WHERE id = $1', [childId]);
      await clientA.query('DELETE FROM users WHERE id = $1', [parentId]);
      await clientA.query('COMMIT');

      await assert.rejects(
        () => insertPromise,
        (err: unknown) => {
          const code =
            err && typeof err === 'object' && 'code' in err
              ? String((err as { code?: string }).code)
              : '';
          return code === '23503';
        },
      );

      const leftover = await pool.query(
        `SELECT 1 FROM parent_children WHERE child_id = $1`,
        [extraChildId],
      );
      assert.equal(
        leftover.rowCount,
        0,
        'extra child must not be linked after the parent deletion commits',
      );
      const extraStillThere = await pool.query(
        `SELECT 1 FROM users WHERE id = $1`,
        [extraChildId],
      );
      assert.equal(extraStillThere.rowCount, 1);
    } finally {
      try {
        await clientA.query('ROLLBACK');
      } catch {
        // already committed or idle
      }
      clientA.release();
      clientB.release();
      await pool.query(`DELETE FROM users WHERE id = ANY($1::uuid[])`, [
        [parentId, childId, extraChildId],
      ]);
      await pool.end();
    }
  });
});
