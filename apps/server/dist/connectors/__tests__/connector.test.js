"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const node_assert_1 = __importDefault(require("node:assert"));
const connector_service_1 = require("../../services/connector.service");
const echo_1 = require("../echo");
const base_1 = require("../base");
// Mock connector for testing registry
class DummyConnector extends base_1.BaseConnector {
    async validateConfig(config) {
        return true;
    }
    async *sendMessage(params) {
        yield 'dummy';
    }
    async getStatus(config) {
        return 'online';
    }
}
(0, node_test_1.default)('ConnectorRegistry - Registration and Retrieval', async (t) => {
    await t.test('should have "echo" registered by default', () => {
        const registry = new connector_service_1.ConnectorRegistry();
        const connector = registry.get('echo');
        node_assert_1.default.ok(connector instanceof echo_1.EchoConnector);
    });
    await t.test('should register and retrieve new connectors', () => {
        const registry = new connector_service_1.ConnectorRegistry();
        const dummy = new DummyConnector();
        registry.register('dummy', dummy);
        node_assert_1.default.strictEqual(registry.get('dummy'), dummy);
    });
    await t.test('should throw error for unknown connector type', () => {
        const registry = new connector_service_1.ConnectorRegistry();
        node_assert_1.default.throws(() => {
            registry.get('unregistered');
        }, /Unknown connector type: unregistered/);
    });
});
(0, node_test_1.default)('EchoConnector - Functionality', async (t) => {
    const connector = new echo_1.EchoConnector();
    await t.test('validateConfig should return true for valid object config', async () => {
        const isValid = await connector.validateConfig({});
        node_assert_1.default.strictEqual(isValid, true);
    });
    await t.test('validateConfig should throw for non-object config', async () => {
        await node_assert_1.default.rejects(async () => {
            await connector.validateConfig(null);
        }, /Invalid config/);
    });
    await t.test('getStatus should return "online"', async () => {
        const status = await connector.getStatus({});
        node_assert_1.default.strictEqual(status, 'online');
    });
    await t.test('sendMessage should stream back user last message with echo prefix', async () => {
        const stream = connector.sendMessage({
            messages: [
                { role: 'user', content: 'hello' },
                { role: 'user', content: 'stream test message' },
            ],
            threadId: 'test-thread',
            config: {},
        });
        const chunks = [];
        for await (const chunk of stream) {
            chunks.push(chunk);
        }
        node_assert_1.default.deepStrictEqual(chunks, ['Echo: stream test message']);
    });
});
