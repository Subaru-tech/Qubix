export abstract class BaseConnector {
  /**
   * Validates the configuration for this connector type.
   * Returns true if valid, or throws a descriptive error if invalid.
   */
  abstract validateConfig(config: Record<string, unknown>): Promise<boolean>;

  /**
   * Sends a message payload to the model/endpoint and yields streamed string chunks.
   */
  abstract sendMessage(params: {
    messages: Array<{ role: string; content: string }>;
    threadId: string;
    config: Record<string, unknown>;
  }): AsyncIterable<string>;

  /**
   * Verifies the connection and returns the connectivity status of the connector.
   */
  abstract getStatus(config: Record<string, unknown>): Promise<'online' | 'offline' | 'error'>;
}
