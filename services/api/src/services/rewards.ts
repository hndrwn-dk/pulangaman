import { pool } from '../db/pool.js';
import { broadcastToRoom, childRoom } from '../ws/server.js';
import { sendFcmToUser } from './fcm.js';

type AwardParams = {
  childId: string;
  actorId?: string | null;
  delta: number;
  reason: string;
  referenceKey: string;
  metadata?: Record<string, unknown>;
};

export async function awardReward(params: AwardParams): Promise<boolean> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const ledger = await client.query(
      `INSERT INTO reward_ledger
         (child_id, actor_id, delta, reason, reference_key, metadata)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb)
       ON CONFLICT (reference_key) DO NOTHING
       RETURNING id`,
      [
        params.childId,
        params.actorId ?? null,
        params.delta,
        params.reason,
        params.referenceKey,
        JSON.stringify(params.metadata ?? {}),
      ],
    );
    if (ledger.rowCount === 0) {
      await client.query('ROLLBACK');
      return false;
    }

    await client.query(
      `INSERT INTO reward_balances
         (child_id, points, current_streak, longest_streak, last_award_date)
       VALUES ($1, GREATEST(0, $2), 1, 1, CURRENT_DATE)
       ON CONFLICT (child_id) DO UPDATE SET
         points = GREATEST(0, reward_balances.points + $2),
         current_streak = CASE
           WHEN reward_balances.last_award_date = CURRENT_DATE THEN reward_balances.current_streak
           WHEN reward_balances.last_award_date = CURRENT_DATE - 1 THEN reward_balances.current_streak + 1
           ELSE 1
         END,
         longest_streak = GREATEST(
           reward_balances.longest_streak,
           CASE
             WHEN reward_balances.last_award_date = CURRENT_DATE THEN reward_balances.current_streak
             WHEN reward_balances.last_award_date = CURRENT_DATE - 1 THEN reward_balances.current_streak + 1
             ELSE 1
           END
         ),
         last_award_date = CURRENT_DATE,
         updated_at = now()`,
      [params.childId, params.delta],
    );

    await client.query(
      `INSERT INTO audit_events (actor_id, subject_child_id, action, payload)
       VALUES ($1, $2, 'reward.awarded', $3::jsonb)`,
      [
        params.actorId ?? null,
        params.childId,
        JSON.stringify({ delta: params.delta, reason: params.reason }),
      ],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  const payload = {
    childId: params.childId,
    delta: params.delta,
    reason: params.reason,
  };
  broadcastToRoom(childRoom(params.childId), 'reward:earned', payload);
  await sendFcmToUser(
    params.childId,
    {
      title: 'Poin PulangAman bertambah',
      body: `Kamu mendapat ${params.delta} poin`,
    },
    { type: 'reward_earned', delta: String(params.delta), reason: params.reason },
  );
  return true;
}
