import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { notifyParentChildJoined } from './childJoinNotify.js';

describe('notifyParentChildJoined', () => {
  it('invokes sendFcmToUser with parentId, childId, and child_detail route', async () => {
    const calls: Array<{
      userId: string;
      notification: { title: string; body: string };
      data?: Record<string, string>;
    }> = [];

    await notifyParentChildJoined('parent-1', 'child-9', 'Alya', async (userId, notification, data) => {
      calls.push({ userId, notification, data });
      return { sent: 1, skipped: false };
    });

    assert.equal(calls.length, 1);
    assert.equal(calls[0].userId, 'parent-1');
    assert.equal(calls[0].data?.childId, 'child-9');
    assert.equal(calls[0].data?.type, 'child_device_joined');
    assert.equal(calls[0].data?.route, 'child_detail');
    assert.equal(calls[0].notification.title, 'PulangAman — Perangkat baru terhubung');
    assert.match(calls[0].notification.body, /Alya/);
  });

  it('swallows rejected sendFcmToUser so join can still return 201 after COMMIT', async () => {
    // No HTTP/DB harness for POST /join; this asserts the post-COMMIT notify
    // path never throws (so status 201 and committed rows are unaffected).
    await assert.doesNotReject(() =>
      notifyParentChildJoined('parent-1', 'child-9', 'Alya', async () => {
        throw new Error('fcm unavailable');
      }),
    );
  });
});
