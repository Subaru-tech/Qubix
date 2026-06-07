import test from 'node:test';
import assert from 'node:assert';
import { ConnectorRegistry } from '../../services/connector.service';
import { EchoConnector } from '../echo';
import { BaseConnector } from '../base';

// Mock connector for testing registry
class DummyConnector extends BaseConnector {
  async validateConfig(config: Record<string, unknown>): Promise<boolean> {
    return true;
  }
  async *sendMessage(params: {
    messages: Array<{ role: string; content: string }>;
    threadId: string;
    config: Record<string, unknown>;
  }): AsyncIterable<string> {
    yield 'dummy';
  }
  async getStatus(config: Record<string, unknown>): Promise<'online' | 'offline' | 'error'> {
    return 'online';
  }
}

test('ConnectorRegistry - Registration and Retrieval', async (t) => {
  await t.test('should have "echo" registered by default', () => {
    const registry = new ConnectorRegistry();
    const connector = registry.get('echo');
    assert.ok(connector instanceof EchoConnector);
  });

  await t.test('should register and retrieve new connectors', () => {
    const registry = new ConnectorRegistry();
    const dummy = new DummyConnector();
    registry.register('dummy', dummy);
    assert.strictEqual(registry.get('dummy'), dummy);
  });

  await t.test('should throw error for unknown connector type', () => {
    const registry = new ConnectorRegistry();
    assert.throws(() => {
      registry.get('unregistered');
    }, /Unknown connector type: unregistered/);
  });
});

test('EchoConnector - Functionality', async (t) => {
  const connector = new EchoConnector();

  await t.test('validateConfig should return true for valid object config', async () => {
    const isValid = await connector.validateConfig({});
    assert.strictEqual(isValid, true);
  });

  await t.test('validateConfig should throw for non-object config', async () => {
    await assert.rejects(async () => {
      await connector.validateConfig(null as any);
    }, /Invalid config/);
  });

  await t.test('getStatus should return "online"', async () => {
    const status = await connector.getStatus({});
    assert.strictEqual(status, 'online');
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

    const chunks: string[] = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }

    assert.deepStrictEqual(chunks, ['Echo: stream test message']);
  });
});
