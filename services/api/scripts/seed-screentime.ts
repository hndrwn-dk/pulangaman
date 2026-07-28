/**
 * Seed screen-time telemetry for heatmap + insights.
 *
 * Modes:
 * 1) DATABASE_URL (+ PARENT_ID or CHILD_IDS) — direct SQL (local or Neon)
 * 2) API_BASE_URL + Bearer token via PARENT_TOKEN — POST /api/v1/screentime/seed-demo
 *
 * Examples:
 *   DATABASE_URL=postgres://... PARENT_ID=<uuid> npm run seed:screentime
 *   PARENT_TOKEN=<firebase-id-token> npm run seed:screentime
 *   PARENT_TOKEN=... DAYS=35 npm run seed:screentime
 */
import 'dotenv/config';
import pg from 'pg';
import {
  listChildrenForParent,
  seedScreenTimeForChildren,
} from '../src/services/seedScreenTime.js';

const days = Number(process.env.DAYS || 35);
const limitMinutes = Number(process.env.LIMIT_MINUTES || 120);
const apiBase = (process.env.API_BASE_URL || 'https://pulangaman-api.onrender.com').replace(
  /\/$/,
  '',
);

async function seedViaApi(token: string): Promise<void> {
  const res = await fetch(`${apiBase}/api/v1/screentime/seed-demo`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      days,
      limitMinutes,
      childIds: process.env.CHILD_IDS
        ? process.env.CHILD_IDS.split(',').map((s) => s.trim()).filter(Boolean)
        : undefined,
    }),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`seed-demo failed ${res.status}: ${text.slice(0, 400)}`);
  }
  console.log(text);
}

async function seedViaDb(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL or PARENT_TOKEN required');
  }

  const client = new pg.Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    let childIds = process.env.CHILD_IDS
      ? process.env.CHILD_IDS.split(',').map((s) => s.trim()).filter(Boolean)
      : [];

    if (childIds.length === 0) {
      const parentId = process.env.PARENT_ID;
      if (!parentId) {
        throw new Error('Set PARENT_ID or CHILD_IDS when using DATABASE_URL');
      }
      const children = await listChildrenForParent(client, parentId);
      childIds = children.map((c) => c.id);
      console.log(
        'Children:',
        children.map((c) => `${c.name ?? '?'} (${c.id})`).join(', '),
      );
    }

    if (childIds.length === 0) {
      throw new Error('No children to seed');
    }

    const results = await seedScreenTimeForChildren(client, {
      childIds,
      days,
      limitMinutes,
    });
    console.log(JSON.stringify({ results }, null, 2));
  } finally {
    await client.end();
  }
}

async function main(): Promise<void> {
  const token = process.env.PARENT_TOKEN;
  if (token) {
    await seedViaApi(token);
    return;
  }
  await seedViaDb();
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
