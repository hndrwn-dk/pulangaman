import { config } from '../config.js';
import { runHomeByCheck } from '../services/homeByService.js';

let timer: NodeJS.Timeout | null = null;

export function startHomeByCheckJob(): void {
  if (timer) return;
  void runHomeByCheck().catch((err) => {
    console.error('home_by_check_failed', err);
  });
  timer = setInterval(() => {
    void runHomeByCheck().catch((err) => {
      console.error('home_by_check_failed', err);
    });
  }, config.HOME_BY_CHECK_INTERVAL_MS);
  timer.unref?.();
}

export function stopHomeByCheckJob(): void {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
