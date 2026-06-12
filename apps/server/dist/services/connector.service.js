"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectorRegistry = exports.ConnectorRegistry = void 0;
const client_1 = require("../db/client");
const echo_1 = require("../connectors/echo");
const openai_1 = require("../connectors/openai");
const webhook_1 = require("../connectors/webhook");
const gemini_1 = require("../connectors/gemini");
class ConnectorRegistry {
    connectors = new Map();
    constructor() {
        // Register all built-in connectors
        this.register('echo', new echo_1.EchoConnector());
        this.register('openai', new openai_1.OpenAIConnector());
        this.register('webhook', new webhook_1.WebhookConnector());
        this.register('gemini', new gemini_1.GeminiConnector());
    }
    /**
     * Registers a connector instance under a given type name.
     */
    register(type, connector) {
        this.connectors.set(type, connector);
    }
    /**
     * Retrieves a connector instance by type name.
     * Throws an error if the connector type is unregistered.
     */
    get(type) {
        const connector = this.connectors.get(type);
        if (!connector) {
            throw new Error(`Unknown connector type: ${type}`);
        }
        return connector;
    }
    /**
     * Returns all registered connector type names.
     */
    getRegisteredTypes() {
        return Array.from(this.connectors.keys());
    }
    /**
     * Checks if a connector type is registered.
     */
    has(type) {
        return this.connectors.has(type);
    }
    /**
     * Fetches an agent under the user's RLS context, resolves the connector, and validates its configuration.
     */
    async testConnection(agentId, userId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!agent) {
            throw new Error(`Agent not found or unauthorized: ${agentId}`);
        }
        const connector = this.get(agent.connectorType);
        return connector.validateConfig(agent.config);
    }
    /**
     * Fetches an agent under the user's RLS context and returns its connectivity status.
     */
    async getAgentStatus(agentId, userId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!agent) {
            throw new Error(`Agent not found or unauthorized: ${agentId}`);
        }
        const connector = this.get(agent.connectorType);
        return connector.getStatus(agent.config);
    }
    /**
     * Fetches an agent under the user's RLS context, maps the messages, and streams agent response chunks.
     */
    async streamMessage(agentId, messages, userId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
            ...agent.config,
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
exports.ConnectorRegistry = ConnectorRegistry;
// Export a singleton instance of the registry
exports.connectorRegistry = new ConnectorRegistry();
