import { Redis } from 'ioredis';
import { config } from '../config.js';

let redis: Redis | null = null;

export function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(config.REDIS_URL, {
      maxRetriesPerRequest: 1,
      lazyConnect: true,
    });
  }
  return redis;
}

export async function checkRedis(): Promise<boolean> {
  const client = getRedis();
  if (client.status !== 'ready') {
    await client.connect();
  }
  const pong = await client.ping();
  return pong === 'PONG';
}

export function childLocationKey(childId: string): string {
  return `loc:child:${childId}`;
}

export function guardianPresenceKey(guardianId: string): string {
  return `presence:guardian:${guardianId}`;
}
