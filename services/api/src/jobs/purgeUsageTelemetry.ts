import { pool } from '../db/pool.js';
import { config } from '../config.js';

let timer: NodeJS.Timeout | null = null;

export async function purgeUsageTelemetry(): Promise<number> {
  const result = await pool.query(
    `DELETE FROM usage_telemetry
     WHERE recorded_at < now() - ($1::text || ' days')::interval`,
    [String(config.USAGE_RETENTION_DAYS)],
  );
  return result.rowCount ?? 0;
}

export function startUsageTelemetryPurgeJob(): void {
  if (timer) return;
  void purgeUsageTelemetry();
  timer = setInterval(() => void purgeUsageTelemetry(), config.PURGE_INTERVAL_MS);
  timer.unref?.();
}
