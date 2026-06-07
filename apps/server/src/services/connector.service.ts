import { Message } from '@prisma/client';
import { prisma } from '../db/client';
import { BaseConnector } from '../connectors/base';
import { EchoConnector } from '../connectors/echo';

export class ConnectorRegistry {
  private connectors = new Map<string, BaseConnector>();

  constructor() {
    // Automatically register default connectors
    this.register('echo', new EchoConnector());
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
   * Fetches an agent under the user's RLS context, resolves the connector, and validates its configuration.
   */
  async testConnection(agentId: string, userId: string): Promise<boolean> {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findUnique({
        where: { id: agentId },
      });
    });

    if (!agent) {
      throw new Error(`Agent not found or unauthorized: ${agentId}`);
    }

    const connector = this.get(agent.connectorType);
    return connector.validateConfig(agent.config as Record<string, unknown>);
  }

  /**
   * Fetches an agent under the user's RLS context, maps the messages, and streams agent response chunks.
   */
  async streamMessage(agentId: string, messages: Message[], userId: string): Promise<AsyncIterable<string>> {
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findUnique({
        where: { id: agentId },
      });
    });

    if (!agent) {
      throw new Error(`Agent not found or unauthorized: ${agentId}`);
    }

    const connector = this.get(agent.connectorType);

    // Map Message model to the format expected by the BaseConnector
    const mappedMessages = messages.map((msg) => ({
      role: msg.role,
      content: msg.content,
    }));

    const threadId = messages[0]?.threadId || 'default-thread';

    return connector.sendMessage({
      messages: mappedMessages,
      threadId,
      config: agent.config as Record<string, unknown>,
    });
  }
}

// Export a singleton instance of the registry
export const connectorRegistry = new ConnectorRegistry();
