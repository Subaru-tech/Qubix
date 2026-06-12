import { FastifyInstance } from 'fastify';
import websocket from '@fastify/websocket';
import { WebSocket } from 'ws';
import { redisSub } from '../db/redis';
import { verifyToken } from './auth';

interface ClientState {
  userId: string;
  subscriptions: Set<string>;
}

const MAX_SUBSCRIPTIONS = 50;

export async function websocketPlugin(fastify: FastifyInstance) {
  await fastify.register(websocket);

  fastify.get('/ws', { websocket: true }, (socket: WebSocket, request) => {
    const state: ClientState = {
      userId: '',
      subscriptions: new Set(),
    };

    let authenticated = false;

    // 5-second auth timeout — disconnect if not authenticated
    const authTimeout = setTimeout(() => {
      if (!authenticated) {
        socket.send(JSON.stringify({ type: 'error', error: 'Authentication timeout' }));
        socket.close(4001, 'Authentication timeout');
      }
    }, 5000);

    socket.on('message', async (raw: Buffer) => {
      let msg: any;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        socket.send(JSON.stringify({ type: 'error', error: 'Invalid JSON' }));
        return;
      }

      // Handle authentication
      if (msg.type === 'auth') {
        try {
          const { userId } = await verifyToken(msg.token);
          state.userId = userId;
          authenticated = true;
          clearTimeout(authTimeout);
          socket.send(JSON.stringify({ type: 'auth:success', userId }));
          request.log.info({ userId }, 'WebSocket authenticated');
        } catch {
          socket.send(JSON.stringify({ type: 'error', error: 'Invalid token' }));
          socket.close(4003, 'Invalid token');
        }
        return;
      }

      // All other messages require authentication
      if (!authenticated) {
        socket.send(JSON.stringify({ type: 'error', error: 'Not authenticated' }));
        return;
      }

      switch (msg.type) {
        case 'subscribe:thread': {
          const threadId = msg.threadId;
          if (!threadId || typeof threadId !== 'string') {
            socket.send(JSON.stringify({ type: 'error', error: 'Missing threadId' }));
            return;
          }

          if (state.subscriptions.size >= MAX_SUBSCRIPTIONS) {
            socket.send(JSON.stringify({
              type: 'error',
              error: `Max subscriptions (${MAX_SUBSCRIPTIONS}) reached`,
            }));
            return;
          }

          const channel = `thread:${threadId}:stream`;

          if (!state.subscriptions.has(channel)) {
            state.subscriptions.add(channel);
            await redisSub.subscribe(channel);
          }

          socket.send(JSON.stringify({ type: 'subscribed', threadId }));
          break;
        }

        case 'unsubscribe:thread': {
          const threadId = msg.threadId;
          const channel = `thread:${threadId}:stream`;

          if (state.subscriptions.has(channel)) {
            state.subscriptions.delete(channel);
            await redisSub.unsubscribe(channel);
          }

          socket.send(JSON.stringify({ type: 'unsubscribed', threadId }));
          break;
        }

        case 'ping': {
          socket.send(JSON.stringify({ type: 'pong' }));
          break;
        }

        default: {
          socket.send(JSON.stringify({ type: 'error', error: `Unknown type: ${msg.type}` }));
        }
      }
    });

    // Forward Redis pub-sub messages to this socket
    const messageHandler = (channel: string, message: string) => {
      if (state.subscriptions.has(channel) && socket.readyState === WebSocket.OPEN) {
        socket.send(message);
      }
    };

    redisSub.on('message', messageHandler);

    // Cleanup on disconnect
    socket.on('close', async () => {
      clearTimeout(authTimeout);
      redisSub.off('message', messageHandler);

      // Unsubscribe from all channels
      for (const channel of state.subscriptions) {
        await redisSub.unsubscribe(channel).catch(() => {});
      }
      state.subscriptions.clear();

      if (state.userId) {
        request.log.info({ userId: state.userId }, 'WebSocket disconnected');
      }
    });

    socket.on('error', (err: Error) => {
      request.log.error({ err }, 'WebSocket error');
    });
  });
}
