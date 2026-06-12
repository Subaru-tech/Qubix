import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { authenticate } from '../plugins/auth';
import { AgentService } from '../services/agent.service';
import { connectorRegistry } from '../services/connector.service';

const createAgentSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  connectorType: z.string().min(1),
  config: z.record(z.unknown()),
  systemPrompt: z.string().optional(),
});

const updateAgentSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().optional(),
  config: z.record(z.unknown()).optional(),
  systemPrompt: z.string().optional(),
  isEnabled: z.boolean().optional(),
});

export async function agentRoutes(fastify: FastifyInstance) {
  // All agent routes require authentication
  fastify.addHook('preHandler', authenticate);

  // GET /agents — List all agents
  fastify.get('/', async (request, reply) => {
    try {
      const agents = await AgentService.listAgents(request.userId!);
      return reply.send(agents);
    } catch (err) {
      request.log.error({ err }, 'Failed to list agents');
      return reply.status(500).send({ error: 'Internal server error' });
    }
  });

  // POST /agents — Create new agent
  fastify.post('/', async (request, reply) => {
    try {
      const body = createAgentSchema.parse(request.body);

      // Validate connector type exists
      if (!connectorRegistry.has(body.connectorType)) {
        return reply.status(400).send({
          error: `Unknown connector type: ${body.connectorType}`,
          availableTypes: connectorRegistry.getRegisteredTypes(),
        });
      }

      const agent = await AgentService.createAgent(request.userId!, body);
      return reply.status(201).send(agent);
    } catch (err) {
      if (err instanceof z.ZodError) {
        return reply.status(400).send({ error: 'Validation failed', details: err.format() });
      }
      request.log.error({ err }, 'Failed to create agent');
      return reply.status(500).send({ error: 'Internal server error' });
    }
  });

  // GET /agents/:id — Get single agent
  fastify.get('/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string };
      const agent = await AgentService.getAgent(request.userId!, id);

      if (!agent) {
        return reply.status(404).send({ error: 'Not found' });
      }

      return reply.send(agent);
    } catch (err) {
      request.log.error({ err }, 'Failed to get agent');
      return reply.status(500).send({ error: 'Internal server error' });
    }
  });

  // PUT /agents/:id — Update agent
  fastify.put('/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string };
      const body = updateAgentSchema.parse(request.body);

      const agent = await AgentService.updateAgent(request.userId!, id, body);

      if (!agent) {
        return reply.status(404).send({ error: 'Not found' });
      }

      return reply.send(agent);
    } catch (err) {
      if (err instanceof z.ZodError) {
        return reply.status(400).send({ error: 'Validation failed', details: err.format() });
      }
      request.log.error({ err }, 'Failed to update agent');
      return reply.status(500).send({ error: 'Internal server error' });
    }
  });

  // DELETE /agents/:id — Delete agent
  fastify.delete('/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string };
      const deleted = await AgentService.deleteAgent(request.userId!, id);

      if (!deleted) {
        return reply.status(404).send({ error: 'Not found' });
      }

      return reply.status(204).send();
    } catch (err) {
      request.log.error({ err }, 'Failed to delete agent');
      return reply.status(500).send({ error: 'Internal server error' });
    }
  });

  // POST /agents/:id/test — Test agent connection
  fastify.post('/:id/test', async (request, reply) => {
    try {
      const { id } = request.params as { id: string };
      const result = await AgentService.testAgentConnection(request.userId!, id);

      if (!result) {
        return reply.status(404).send({ error: 'Not found' });
      }

      // Always return 200 — success: false means the test ran but the agent is unreachable
      return reply.send(result);
    } catch (err) {
      request.log.error({ err }, 'Failed to test agent connection');
      return reply.send({
        success: false,
        status: 'error',
        error: (err as Error).message,
      });
    }
  });
}
