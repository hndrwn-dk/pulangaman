type SendFcmToUser = (
  userId: string,
  notification: { title: string; body: string },
  data?: Record<string, string>,
) => Promise<unknown>;

/**
 * Notify parent after a child device successfully joins.
 * Failures are swallowed so join response is never blocked.
 * Optional `sendFcm` is for unit tests (no HTTP harness for /join).
 */
export async function notifyParentChildJoined(
  parentId: string,
  childId: string,
  displayName: string,
  sendFcm?: SendFcmToUser,
): Promise<void> {
  const send =
    sendFcm ?? (await import('../services/fcm.js')).sendFcmToUser;
  await send(
    parentId,
    {
      title: 'PulangAman — Perangkat baru terhubung',
      body: `${displayName} baru saja bergabung. Ketuk untuk memeriksa jika ini bukan Anda.`,
    },
    {
      type: 'child_device_joined',
      childId,
      route: 'child_detail',
    },
  ).catch((err) => {
    console.error('child_join_notify_failed', { childId, err });
  });
}
