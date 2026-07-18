import type { Server } from 'node:http';
import { WebSocketServer, type WebSocket } from 'ws';
import { verifyIdToken } from '../firebase/admin.js';
import { pool } from '../db/pool.js';

type Client = {
  socket: WebSocket;
  firebaseUid: string;
  userId?: string;
  rooms: Set<string>;
};

const clients = new Set<Client>();

function send(socket: WebSocket, event: string, payload: unknown) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify({ event, payload }));
  }
}

export function childRoom(childId: string): string {
  return `child:${childId}`;
}

export function guardianAlertRoom(guardianId: string): string {
  return `guardian:${guardianId}`;
}

async function canSubscribe(userId: string | undefined, room: string): Promise<boolean> {
  if (!userId) {
    return false;
  }

  if (room.startsWith('child:')) {
    const childId = room.slice('child:'.length);
    const parentLink = await pool.query(
      `SELECT 1 FROM parent_children WHERE parent_id = $1 AND child_id = $2`,
      [userId, childId],
    );
    if ((parentLink.rowCount ?? 0) > 0) {
      return true;
    }
    if (childId === userId) {
      return true;
    }
    const guardianLink = await pool.query(
      `SELECT 1 FROM child_approved_guardians
       WHERE guardian_id = $1 AND child_id = $2 AND status = 'active'`,
      [userId, childId],
    );
    return (guardianLink.rowCount ?? 0) > 0;
  }

  if (room.startsWith('guardian:')) {
    const guardianId = room.slice('guardian:'.length);
    return guardianId === userId;
  }

  if (room.startsWith('alert:')) {
    const alertId = room.slice('alert:'.length);
    const access = await pool.query(
      `SELECT 1 FROM panic_alerts pa
       LEFT JOIN panic_alert_recipients par ON par.alert_id = pa.id AND par.user_id = $2
       WHERE pa.id = $1
         AND (
           pa.parent_id = $2
           OR pa.child_id = $2
           OR par.user_id IS NOT NULL
         )`,
      [alertId, userId],
    );
    return (access.rowCount ?? 0) > 0;
  }

  return false;
}

export function attachWebSocketServer(server: Server): WebSocketServer {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', async (socket, req) => {
    try {
      const url = new URL(req.url ?? '', 'http://localhost');
      const token = url.searchParams.get('token');
      if (!token) {
        socket.close(4401, 'missing_token');
        return;
      }

      const verified = await verifyIdToken(token);
      const userResult = await pool.query<{ id: string }>(
        `SELECT id FROM users WHERE firebase_uid = $1 AND is_active = true LIMIT 1`,
        [verified.uid],
      );

      const client: Client = {
        socket,
        firebaseUid: verified.uid,
        userId: userResult.rows[0]?.id,
        rooms: new Set(),
      };
      clients.add(client);

      send(socket, 'connected', {
        firebaseUid: verified.uid,
        userId: client.userId ?? null,
      });

      socket.on('message', (raw) => {
        void (async () => {
          try {
            const message = JSON.parse(String(raw)) as {
              action?: string;
              room?: string;
            };

            if (message.action === 'subscribe' && message.room) {
              if (client.rooms.size >= 20) {
                send(socket, 'error', { error: 'too_many_subscriptions' });
                return;
              }
              const allowed = await canSubscribe(client.userId, message.room);
              if (!allowed) {
                send(socket, 'error', { error: 'forbidden_room', room: message.room });
                return;
              }
              client.rooms.add(message.room);
              send(socket, 'subscribed', { room: message.room });
              return;
            }

            if (message.action === 'unsubscribe' && message.room) {
              client.rooms.delete(message.room);
              send(socket, 'unsubscribed', { room: message.room });
            }
          } catch {
            send(socket, 'error', { error: 'invalid_message' });
          }
        })();
      });

      socket.on('close', () => {
        clients.delete(client);
      });
    } catch {
      socket.close(4401, 'invalid_token');
    }
  });

  return wss;
}

export function broadcastToRoom(room: string, event: string, payload: unknown) {
  for (const client of clients) {
    if (client.rooms.has(room)) {
      send(client.socket, event, payload);
    }
  }
}
