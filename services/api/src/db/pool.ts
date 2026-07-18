import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

const requiresSsl =
  config.NODE_ENV === 'production' ||
  /sslmode=require|neon\.tech|render\.com|\.aws\./i.test(config.DATABASE_URL);

export const pool = new Pool({
  connectionString: config.DATABASE_URL,
  ssl: requiresSsl ? { rejectUnauthorized: false } : undefined,
});

export async function checkDatabase(): Promise<boolean> {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
    return true;
  } finally {
    client.release();
  }
}
