import { BaseConnector } from './base';

export class EchoConnector extends BaseConnector {
  /**
   * Validates config. For echo, we just check if it's a valid object.
   */
  async validateConfig(config: Record<string, unknown>): Promise<boolean> {
    if (!config || typeof config !== 'object') {
      throw new Error('Invalid config: configuration must be a non-null object');
    }
    return true;
  }

  /**
   * Immediately streams the user's last message back as a single chunk.
   */
  async *sendMessage(params: {
    messages: Array<{ role: string; content: string }>;
    threadId: string;
    config: Record<string, unknown>;
  }): AsyncIterable<string> {
    const lastMessage = params.messages[params.messages.length - 1];
    const content = lastMessage ? lastMessage.content : '';
    yield `Echo: ${content}`;
  }

  /**
   * Echo connector is always online.
   */
  async getStatus(config: Record<string, unknown>): Promise<'online' | 'offline' | 'error'> {
    await this.validateConfig(config);
    return 'online';
  }
}
