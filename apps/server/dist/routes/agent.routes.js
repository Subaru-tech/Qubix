"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.agentRoutes = agentRoutes;
const zod_1 = require("zod");
const auth_1 = require("../plugins/auth");
const agent_service_1 = require("../services/agent.service");
const connector_service_1 = require("../services/connector.service");
const createAgentSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).max(100),
    description: zod_1.z.string().optional(),
    connectorType: zod_1.z.string().min(1),
    config: zod_1.z.record(zod_1.z.unknown()),
    systemPrompt: zod_1.z.string().optional(),
});
const updateAgentSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).max(100).optional(),
    description: zod_1.z.string().optional(),
    config: zod_1.z.record(zod_1.z.unknown()).optional(),
    systemPrompt: zod_1.z.string().optional(),
    isEnabled: zod_1.z.boolean().optional(),
});
async function agentRoutes(fastify) {
    // All agent routes require authentication
    fastify.addHook('preHandler', auth_1.authenticate);
    // GET /agents — List all agents
    fastify.get('/', async (request, reply) => {
        try {
            const agents = await agent_service_1.AgentService.listAgents(request.userId);
            return reply.send(agents);
        }
        catch (err) {
            request.log.error({ err }, 'Failed to list agents');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // POST /agents — Create new agent
    fastify.post('/', async (request, reply) => {
        try {
            const body = createAgentSchema.parse(request.body);
            // Validate connector type exists
            if (!connector_service_1.connectorRegistry.has(body.connectorType)) {
                return reply.status(400).send({
                    error: `Unknown connector type: ${body.connectorType}`,
                    availableTypes: connector_service_1.connectorRegistry.getRegisteredTypes(),
                });
            }
            const agent = await agent_service_1.AgentService.createAgent(request.userId, body);
            return reply.status(201).send(agent);
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            request.log.error({ err }, 'Failed to create agent');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // GET /agents/:id — Get single agent
    fastify.get('/:id', async (request, reply) => {
        try {
            const { id } = request.params;
            const agent = await agent_service_1.AgentService.getAgent(request.userId, id);
            if (!agent) {
                return reply.status(404).send({ error: 'Not found' });
            }
            return reply.send(agent);
        }
        catch (err) {
            request.log.error({ err }, 'Failed to get agent');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // PUT /agents/:id — Update agent
    fastify.put('/:id', async (request, reply) => {
        try {
            const { id } = request.params;
            const body = updateAgentSchema.parse(request.body);
            const agent = await agent_service_1.AgentService.updateAgent(request.userId, id, body);
            if (!agent) {
                return reply.status(404).send({ error: 'Not found' });
            }
            return reply.send(agent);
        }
        catch (err) {
            if (err instanceof zod_1.z.ZodError) {
                return reply.status(400).send({ error: 'Validation failed', details: err.format() });
            }
            request.log.error({ err }, 'Failed to update agent');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // DELETE /agents/:id — Delete agent
    fastify.delete('/:id', async (request, reply) => {
        try {
            const { id } = request.params;
            const deleted = await agent_service_1.AgentService.deleteAgent(request.userId, id);
            if (!deleted) {
                return reply.status(404).send({ error: 'Not found' });
            }
            return reply.status(204).send();
        }
        catch (err) {
            request.log.error({ err }, 'Failed to delete agent');
            return reply.status(500).send({ error: 'Internal server error' });
        }
    });
    // POST /agents/:id/test — Test agent connection
    fastify.post('/:id/test', async (request, reply) => {
        try {
            const { id } = request.params;
            const result = await agent_service_1.AgentService.testAgentConnection(request.userId, id);
            if (!result) {
                return reply.status(404).send({ error: 'Not found' });
            }
            // Always return 200 — success: false means the test ran but the agent is unreachable
            return reply.send(result);
        }
        catch (err) {
            request.log.error({ err }, 'Failed to test agent connection');
            return reply.send({
                success: false,
                status: 'error',
                error: err.message,
            });
        }
    });
}
