import { pool } from '../db/pool.js';
import { config } from '../config.js';

let timer: NodeJS.Timeout | null = null;

export async function purgeLocationHistory(): Promise<number> {
  const result = await pool.query(
    `DELETE FROM location_history
     WHERE recorded_at < now() - ($1::text || ' days')::interval`,
    [String(config.LOCATION_RETENTION_DAYS)],
  );
  const deleted = result.rowCount ?? 0;
  if (deleted > 0) {
    console.info('location_history_purged', {
      deleted,
      retentionDays: config.LOCATION_RETENTION_DAYS,
    });
  }
  return deleted;
}

export function startLocationPurgeJob(): void {
  if (timer) {
    return;
  }
  void purgeLocationHistory();
  timer = setInterval(() => {
    void purgeLocationHistory();
  }, config.PURGE_INTERVAL_MS);
  timer.unref?.();
}

export function stopLocationPurgeJob(): void {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
