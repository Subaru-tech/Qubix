import type { Message } from '@prisma/client';
import { prisma } from '../db/client';
import { BaseConnector } from '../connectors/base';
import { EchoConnector } from '../connectors/echo';
import { OpenAIConnector } from '../connectors/openai';
import { WebhookConnector } from '../connectors/webhook';

export class ConnectorRegistry {
  private connectors = new Map<string, BaseConnector>();

  constructor() {
    // Register all built-in connectors
    this.register('echo', new EchoConnector());
    this.register('openai', new OpenAIConnector());
    this.register('webhook', new WebhookConnector());
  }

  /**
   * Registers a connector instance under a given type name.
   */
  register(type: string, connector: BaseConnector): void {
    this.connectors.set(type, connector);
  }

  /**
   * Retrieves a connector instance by type name.
   * Throws an error if the connector type is unregistered.
   */
  get(type: string): BaseConnector {
    const connector = this.connectors.get(type);
    if (!connector) {
      throw new Error(`Unknown connector type: ${type}`);
    }
    return connector;
  }

  /**
   * Returns all registered connector type names.
   */
  getRegisteredTypes(): string[] {
    return Array.from(this.connectors.keys());
  }

  /**
   * Checks if a connector type is registered.
   */
  has(type: string): boolean {
    return this.connectors.has(type);
  }

  /**
   * Fetches an agent under the user's RLS context, resolves the connector, and validates its configuration.
   */
  async testConnection(agentId: string, userId: string): Promise<boolean> {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!agent) {
      throw new Error(`Agent not found or unauthorized: ${agentId}`);
    }

    const connector = this.get(agent.connectorType);
    return connector.validateConfig(agent.config as Record<string, unknown>);
  }

  /**
   * Fetches an agent under the user's RLS context and returns its connectivity status.
   */
  async getAgentStatus(agentId: string, userId: string): Promise<'online' | 'offline' | 'error'> {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!agent) {
      throw new Error(`Agent not found or unauthorized: ${agentId}`);
    }

    const connector = this.get(agent.connectorType);
    return connector.getStatus(agent.config as Record<string, unknown>);
  }

  /**
   * Fetches an agent under the user's RLS context, maps the messages, and streams agent response chunks.
   */
  async streamMessage(agentId: string, messages: Message[], userId: string): Promise<AsyncIterable<string>> {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
      });
    });

    if (!agent) {
      throw new Error(`Agent not found or unauthorized: ${agentId}`);
    }

    const connector = this.get(agent.connectorType);

    // Build config with systemPrompt injected for connectors that support it
    const config = {
      ...(agent.config as Record<string, unknown>),
      ...(agent.systemPrompt ? { systemPrompt: agent.systemPrompt } : {}),
    };

    // Map Message model to the format expected by the BaseConnector
    const mappedMessages = messages.map((msg) => ({
      role: msg.role,
      content: msg.content,
    }));

    const threadId = messages[0]?.threadId || 'default-thread';

    return connector.sendMessage({
      messages: mappedMessages,
      threadId,
      config,
    });
  }
}

// Export a singleton instance of the registry
export const connectorRegistry = new ConnectorRegistry();
