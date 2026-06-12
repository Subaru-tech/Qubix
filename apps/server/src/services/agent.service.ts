import { prisma } from '../db/client';
import { connectorRegistry } from './connector.service';
import { maskConfig } from '../utils/mask-config';
import { ConnectorError } from '../connectors/errors';

interface CreateAgentInput {
  name: string;
  description?: string;
  connectorType: string;
  config: Record<string, unknown>;
  systemPrompt?: string;
}

interface UpdateAgentInput {
  name?: string;
  description?: string;
  config?: Record<string, unknown>;
  systemPrompt?: string;
  isEnabled?: boolean;
}

function sanitizeAgent(agent: any) {
  return {
    id: agent.id,
    name: agent.name,
    description: agent.description,
    connectorType: agent.connectorType,
    config: maskConfig((agent.config || {}) as Record<string, unknown>),
    systemPrompt: agent.systemPrompt,
    isEnabled: agent.isEnabled,
    status: agent.status,
    lastUsedAt: agent.lastUsedAt,
    createdAt: agent.createdAt,
    updatedAt: agent.updatedAt,
  };
}

export const AgentService = {
  /**
   * List all agents for a user, sorted by lastUsedAt then createdAt.
   */
  async listAgents(userId: string) {
    const agents = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findMany({
        where: { userId },
        orderBy: [{ lastUsedAt: 'desc' }, { createdAt: 'desc' }],
      });
    });

    return agents.map(sanitizeAgent);
  },

  /**
   * Create a new agent. Validates that the connector type is registered.
   */
  async createAgent(userId: string, input: CreateAgentInput) {
    // Validate connector type
    if (!connectorRegistry.has(input.connectorType)) {
      throw new Error(`Unknown connector type: ${input.connectorType}`);
    }

    // Validate name length
    if (!input.name || input.name.length < 1 || input.name.length > 100) {
      throw new Error('Agent name must be between 1 and 100 characters');
    }

    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.create({
        data: {
          userId,
          name: input.name,
          description: input.description || null,
          connectorType: input.connectorType,
          config: input.config,
          systemPrompt: input.systemPrompt || null,
          status: 'offline',
        },
      });
    });

    return sanitizeAgent(agent);
  },

  /**
   * Get a single agent by ID. Returns null if not found or not owned.
   */
  async getAgent(userId: string, agentId: string) {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!agent) return null;
    return sanitizeAgent(agent);
  },

  /**
   * Update agent fields. Resets status to offline if config is changed.
   */
  async updateAgent(userId: string, agentId: string, input: UpdateAgentInput) {
    // Verify ownership
    const existing = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!existing) return null;

    const data: any = {};
    if (input.name !== undefined) data.name = input.name;
    if (input.description !== undefined) data.description = input.description;
    if (input.systemPrompt !== undefined) data.systemPrompt = input.systemPrompt;
    if (input.isEnabled !== undefined) data.isEnabled = input.isEnabled;
    if (input.config !== undefined) {
      data.config = input.config;
      data.status = 'offline'; // Reset status when config changes
    }

    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.update({
        where: { id: agentId },
        data,
      });
    });

    return sanitizeAgent(agent);
  },

  /**
   * Delete an agent. Messages referencing this agent will have agentId set to null (SetNull).
   */
  async deleteAgent(userId: string, agentId: string): Promise<boolean> {
    const existing = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!existing) return false;

    await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.delete({
        where: { id: agentId },
      });
    });

    return true;
  },

  /**
   * Test an agent's connection. Returns status and updates the agent record.
   */
  async testAgentConnection(userId: string, agentId: string) {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!agent) return null;

    let status: 'online' | 'offline' | 'error' = 'error';
    let error: string | undefined;

    try {
      const connector = connectorRegistry.get(agent.connectorType);
      status = await connector.getStatus(agent.config as Record<string, unknown>);
    } catch (err) {
      status = 'error';
      error = err instanceof ConnectorError ? err.message : (err as Error).message;
    }

    // Update status in database
    await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.update({
        where: { id: agentId },
        data: { status },
      });
    });

    return {
      success: status === 'online',
      status,
      error,
    };
  },
};
