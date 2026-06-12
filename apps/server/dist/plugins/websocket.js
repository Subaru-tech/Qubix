"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.websocketPlugin = websocketPlugin;
const websocket_1 = __importDefault(require("@fastify/websocket"));
const ws_1 = require("ws");
const redis_1 = require("../db/redis");
const auth_1 = require("./auth");
const MAX_SUBSCRIPTIONS = 50;
async function websocketPlugin(fastify) {
    await fastify.register(websocket_1.default);
    fastify.get('/ws', { websocket: true }, (socket, request) => {
        const state = {
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
        socket.on('message', async (raw) => {
            let msg;
            try {
                msg = JSON.parse(raw.toString());
            }
            catch {
                socket.send(JSON.stringify({ type: 'error', error: 'Invalid JSON' }));
                return;
            }
            // Handle authentication
            if (msg.type === 'auth') {
                try {
                    const { userId } = await (0, auth_1.verifyToken)(msg.token);
                    state.userId = userId;
                    authenticated = true;
                    clearTimeout(authTimeout);
                    socket.send(JSON.stringify({ type: 'auth:success', userId }));
                    request.log.info({ userId }, 'WebSocket authenticated');
                }
                catch {
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
                        await redis_1.redisSub.subscribe(channel);
                    }
                    socket.send(JSON.stringify({ type: 'subscribed', threadId }));
                    break;
                }
                case 'unsubscribe:thread': {
                    const threadId = msg.threadId;
                    const channel = `thread:${threadId}:stream`;
                    if (state.subscriptions.has(channel)) {
                        state.subscriptions.delete(channel);
                        await redis_1.redisSub.unsubscribe(channel);
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
        const messageHandler = (channel, message) => {
            if (state.subscriptions.has(channel) && socket.readyState === ws_1.WebSocket.OPEN) {
                socket.send(message);
            }
        };
        redis_1.redisSub.on('message', messageHandler);
        // Cleanup on disconnect
        socket.on('close', async () => {
            clearTimeout(authTimeout);
            redis_1.redisSub.off('message', messageHandler);
            // Unsubscribe from all channels
            for (const channel of state.subscriptions) {
                await redis_1.redisSub.unsubscribe(channel).catch(() => { });
            }
            state.subscriptions.clear();
            if (state.userId) {
                request.log.info({ userId: state.userId }, 'WebSocket disconnected');
            }
        });
        socket.on('error', (err) => {
            request.log.error({ err }, 'WebSocket error');
        });
    });
}
