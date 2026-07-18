import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  FIREBASE_PROJECT_ID: z.string().optional().default(''),
  CORS_ORIGIN: z.string().default('*'),
  LOCATION_TTL_SECONDS: z.coerce.number().default(900),
  STALE_LOCATION_SECONDS: z.coerce.number().default(120),
  RATE_LIMIT_PER_MINUTE: z.coerce.number().default(100),
  ZONE_DEBOUNCE_SECONDS: z.coerce.number().default(45),
  ZONE_HYSTERESIS_M: z.coerce.number().default(15),
  LOCATION_RETENTION_DAYS: z.coerce.number().default(7),
  PURGE_INTERVAL_MS: z.coerce.number().default(3_600_000),
  PANIC_SMS_DELAY_MS: z.coerce.number().default(30_000),
  PANIC_ESCALATE_DELAY_MS: z.coerce.number().default(60_000),
  SMS_PROVIDER: z.enum(['console', 'http']).default('console'),
  SMS_HTTP_URL: z.string().optional().default(''),
  SMS_HTTP_TOKEN: z.string().optional().default(''),
  KILL_SWITCH_GUARDIAN_NOTIFY: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
  KILL_SWITCH_LOCATION_SHARE: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
  GOOGLE_MAPS_API_KEY: z.string().optional().default(''),
  COMMUNITY_REPORT_TTL_HOURS: z.coerce.number().default(72),
  ROUTE_AVOID_RADIUS_M: z.coerce.number().default(120),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration', parsed.error.flatten().fieldErrors);
  throw new Error('Invalid environment configuration');
}

export const config = parsed.data;
export const isFirebaseConfigured = Boolean(config.FIREBASE_PROJECT_ID);
