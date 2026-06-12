/**
 * Barrel export for all connectors.
 * Importing this module registers all built-in connectors
 * into the singleton ConnectorRegistry.
 */
export { BaseConnector } from './base';
export { EchoConnector } from './echo';
export { OpenAIConnector } from './openai';
export { WebhookConnector } from './webhook';
export * from './errors';
