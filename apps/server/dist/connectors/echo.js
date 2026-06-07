"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EchoConnector = void 0;
const base_1 = require("./base");
class EchoConnector extends base_1.BaseConnector {
    /**
     * Validates config. For echo, we just check if it's a valid object.
     */
    async validateConfig(config) {
        if (!config || typeof config !== 'object') {
            throw new Error('Invalid config: configuration must be a non-null object');
        }
        return true;
    }
    /**
     * Immediately streams the user's last message back as a single chunk.
     */
    async *sendMessage(params) {
        const lastMessage = params.messages[params.messages.length - 1];
        const content = lastMessage ? lastMessage.content : '';
        yield `Echo: ${content}`;
    }
    /**
     * Echo connector is always online.
     */
    async getStatus(config) {
        await this.validateConfig(config);
        return 'online';
    }
}
exports.EchoConnector = EchoConnector;
