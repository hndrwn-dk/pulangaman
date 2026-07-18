import admin from 'firebase-admin';
import { pool } from '../db/pool.js';
import { getFirebaseMessaging, isMessagingAvailable } from '../firebase/admin.js';

export async function sendFcmToUser(
  userId: string,
  notification: { title: string; body: string },
  data: Record<string, string> = {},
): Promise<{ sent: number; skipped: boolean }> {
  const tokens = await pool.query<{ fcm_token: string }>(
    `SELECT fcm_token FROM devices
     WHERE user_id = $1 AND fcm_token IS NOT NULL AND fcm_token <> ''`,
    [userId],
  );

  if (tokens.rowCount === 0) {
    console.info('fcm_skip_no_tokens', { userId });
    return { sent: 0, skipped: true };
  }

  if (!isMessagingAvailable()) {
    console.info('fcm_console_stub', {
      userId,
      notification,
      data,
      tokens: tokens.rows.map((r) => r.fcm_token.slice(0, 12)),
    });
    return { sent: tokens.rowCount ?? 0, skipped: false };
  }

  const messaging = getFirebaseMessaging();
  if (!messaging) {
    return { sent: 0, skipped: true };
  }

  const response = await messaging.sendEachForMulticast({
    tokens: tokens.rows.map((r) => r.fcm_token),
    notification,
    data,
    android: { priority: 'high' },
    apns: {
      payload: {
        aps: { sound: 'default', contentAvailable: true },
      },
    },
  } as admin.messaging.MulticastMessage);

  return { sent: response.successCount, skipped: false };
}
