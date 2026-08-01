import { config } from '../config.js';
import { runWeeklyDigest } from '../services/weeklyDigest.js';

let timer: NodeJS.Timeout | null = null;

export function startWeeklyDigestJob(): void {
  if (timer) return;
  void runWeeklyDigest().catch((err) => {
    console.error('weekly_digest_failed', err);
  });
  timer = setInterval(() => {
    void runWeeklyDigest().catch((err) => {
      console.error('weekly_digest_failed', err);
    });
  }, config.WEEKLY_DIGEST_INTERVAL_MS);
  timer.unref?.();
}

export function stopWeeklyDigestJob(): void {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
