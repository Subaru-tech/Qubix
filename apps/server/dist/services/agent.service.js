"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentService = void 0;
const client_1 = require("../db/client");
const connector_service_1 = require("./connector.service");
const mask_config_1 = require("../utils/mask-config");
const errors_1 = require("../connectors/errors");
function sanitizeAgent(agent) {
    return {
        id: agent.id,
        name: agent.name,
        description: agent.description,
        connectorType: agent.connectorType,
        config: (0, mask_config_1.maskConfig)((agent.config || {})),
        systemPrompt: agent.systemPrompt,
        isEnabled: agent.isEnabled,
        status: agent.status,
        lastUsedAt: agent.lastUsedAt,
        createdAt: agent.createdAt,
        updatedAt: agent.updatedAt,
    };
}
exports.AgentService = {
    /**
     * List all agents for a user, sorted by lastUsedAt then createdAt.
     */
    async listAgents(userId) {
        const agents = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
    async createAgent(userId, input) {
        // Validate connector type
        if (!connector_service_1.connectorRegistry.has(input.connectorType)) {
            throw new Error(`Unknown connector type: ${input.connectorType}`);
        }
        // Validate name length
        if (!input.name || input.name.length < 1 || input.name.length > 100) {
            throw new Error('Agent name must be between 1 and 100 characters');
        }
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
    async getAgent(userId, agentId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!agent)
            return null;
        return sanitizeAgent(agent);
    },
    /**
     * Update agent fields. Resets status to offline if config is changed.
     */
    async updateAgent(userId, agentId, input) {
        // Verify ownership
        const existing = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!existing)
            return null;
        const data = {};
        if (input.name !== undefined)
            data.name = input.name;
        if (input.description !== undefined)
            data.description = input.description;
        if (input.systemPrompt !== undefined)
            data.systemPrompt = input.systemPrompt;
        if (input.isEnabled !== undefined)
            data.isEnabled = input.isEnabled;
        if (input.config !== undefined) {
            data.config = input.config;
            data.status = 'offline'; // Reset status when config changes
        }
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
    async deleteAgent(userId, agentId) {
        const existing = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!existing)
            return false;
        await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.delete({
                where: { id: agentId },
            });
        });
        return true;
    },
    /**
     * Test an agent's connection. Returns status and updates the agent record.
     */
    async testAgentConnection(userId, agentId) {
        const agent = await client_1.prisma.$transactionWithUser(userId, async (tx) => {
            return tx.agent.findFirst({
                where: { id: agentId, userId },
            });
        });
        if (!agent)
            return null;
        let status = 'error';
        let error;
        try {
            const connector = connector_service_1.connectorRegistry.get(agent.connectorType);
            status = await connector.getStatus(agent.config);
        }
        catch (err) {
            status = 'error';
            error = err instanceof errors_1.ConnectorError ? err.message : err.message;
        }
        // Update status in database
        await client_1.prisma.$transactionWithUser(userId, async (tx) => {
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
