import type { Server } from 'node:http';
import { WebSocketServer, type WebSocket } from 'ws';
import { verifyIdToken } from '../firebase/admin.js';

type Client = {
  socket: WebSocket;
  firebaseUid: string;
  rooms: Set<string>;
};

const clients = new Set<Client>();

function send(socket: WebSocket, event: string, payload: unknown) {
  if (socket.readyState === socket.OPEN) {
    socket.send(JSON.stringify({ event, payload }));
  }
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
      const client: Client = {
        socket,
        firebaseUid: verified.uid,
        rooms: new Set(),
      };
      clients.add(client);

      send(socket, 'connected', { firebaseUid: verified.uid });

      socket.on('message', (raw) => {
        try {
          const message = JSON.parse(String(raw)) as {
            action?: string;
            room?: string;
          };
          if (message.action === 'subscribe' && message.room) {
            // Authorization against DB rooms lands in Phase 1.
            client.rooms.add(message.room);
            send(socket, 'subscribed', { room: message.room });
          }
        } catch {
          send(socket, 'error', { error: 'invalid_message' });
        }
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
