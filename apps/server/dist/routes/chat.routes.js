"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.chatRoutes = chatRoutes;
const zod_1 = require("zod");
const auth_1 = require("../plugins/auth");
const chat_service_1 = require("../services/chat.service");
const message_worker_1 = require("../workers/message.worker");
const createThreadSchema = zod_1.z.object({
    agentId: zod_1.z.string().uuid(),
    title: zod_1.z.string().max(200).optional(),
});
const createMessageSchema = zod_1.z.object({
    content: zod_1.z.string().min(1).max(10_000),
});
const switchAgentSchema = zod_1.z.object({
    agentId: zod_1.z.string().uuid(),
});
async function chatRoutes(fastify) {
    // All chat routes require authentication
    fastify.addHook('preHandler', auth_1.authenticate);
    // GET /threads — List user's threads
    fastify.get('/', async (request, reply) => {
        try {
            const threads = await chat_service_1.ChatService.listThreads(request.userId);
            return reply.send(threads);
        }
        catch (err) {
            request.log.error({ err }, 'Failed to list threads');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // POST /threads — Create new thread
    fastify.post('/', async (request, reply) => {
        try {
            const body = createThreadSchema.parse(request.body);
            const thread = await chat_service_1.ChatService.createThread(request.userId, body);
            return reply.status(201).send(thread);
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            if (err.message === 'Agent not found') {
                return reply.status(400).send({ error: 'Agent not found' });
            }
            request.log.error({ err }, 'Failed to create thread');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // GET /threads/:id/messages — Get paginated messages
    fastify.get('/:id/messages', async (request, reply) => {
        try {
            const { id } = request.params;
            const { cursor, limit } = request.query;
            const parsedLimit = limit ? Math.min(parseInt(limit, 10), 50) : 20;
            const result = await chat_service_1.ChatService.getMessages(request.userId, id, cursor, parsedLimit);
            if (!result) {
                return reply.status(404).send({ error: 'Thread not found' });
            }
            return reply.send(result);
        }
        catch (err) {
            request.log.error({ err }, 'Failed to get messages');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // POST /threads/:id/messages — Send a message
    fastify.post('/:id/messages', async (request, reply) => {
        try {
            const { id } = request.params;
            const body = createMessageSchema.parse(request.body);
            const result = await chat_service_1.ChatService.createMessage(request.userId, id, body);
            if (!result) {
                return reply.status(404).send({ error: 'Thread not found' });
            }
            // Enqueue BullMQ job for agent processing
            if (result.agentId) {
                await message_worker_1.messageQueue.add('process-message', {
                    threadId: id,
                    userMessageId: result.message.id,
                    agentId: result.agentId,
                    userId: request.userId,
                });
            }
            return reply.status(201).send({
                message: result.message,
                agentId: result.agentId,
                processing: true,
            });
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            request.log.error({ err }, 'Failed to send message');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // PUT /threads/:id/agent — Switch active agent
    fastify.put('/:id/agent', async (request, reply) => {
        try {
            const { id } = request.params;
            const body = switchAgentSchema.parse(request.body);
            const thread = await chat_service_1.ChatService.switchAgent(request.userId, id, body.agentId);
            if (!thread) {
                return reply.status(404).send({ error: 'Thread not found' });
            }
            return reply.send(thread);
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            if (err.message === 'Agent not found') {
                return reply.status(400).send({ error: 'Agent not found' });
            }
            request.log.error({ err }, 'Failed to switch agent');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // DELETE /threads/:id — Delete thread
    fastify.delete('/:id', async (request, reply) => {
        try {
            const { id } = request.params;
            const deleted = await chat_service_1.ChatService.deleteThread(request.userId, id);
            if (!deleted) {
                return reply.status(404).send({ error: 'Thread not found' });
            }
            return reply.status(204).send();
        }
        catch (err) {
            request.log.error({ err }, 'Failed to delete thread');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
}
