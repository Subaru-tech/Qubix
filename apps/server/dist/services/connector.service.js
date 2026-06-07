"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectorRegistry = exports.ConnectorRegistry = void 0;
const client_1 = require("../db/client");
const echo_1 = require("../connectors/echo");
class ConnectorRegistry {
    connectors = new Map();
    constructor() {
        // Automatically register default connectors
        this.register('echo', new echo_1.EchoConnector());
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
     * Fetches an agent under the user's RLS context, resolves the connector, and validates its configuration.
     */
    async testConnection(agentId, userId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findUnique({
                where: { id: agentId },
            });
        });
        if (!agent) {
            throw new Error(`Agent not found or unauthorized: ${agentId}`);
        }
        const connector = this.get(agent.connectorType);
        return connector.validateConfig(agent.config);
    }
    /**
     * Fetches an agent under the user's RLS context, maps the messages, and streams agent response chunks.
     */
    async streamMessage(agentId, messages, userId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
            config: agent.config,
        });
    }
}
exports.ConnectorRegistry = ConnectorRegistry;
// Export a singleton instance of the registry
exports.connectorRegistry = new ConnectorRegistry();
