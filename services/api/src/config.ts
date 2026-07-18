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
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('Invalid environment configuration', parsed.error.flatten().fieldErrors);
  throw new Error('Invalid environment configuration');
}

export const config = parsed.data;
export const isFirebaseConfigured = Boolean(config.FIREBASE_PROJECT_ID);
