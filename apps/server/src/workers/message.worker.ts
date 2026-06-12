import { Worker, Job, Queue } from 'bullmq';
import { config } from '../config';
import { publishChunk } from '../db/redis';
import { prisma } from '../db/client';
import { connectorRegistry } from '../services/connector.service';
import { ConnectorError } from '../connectors/errors';

export const messageQueue = new Queue('process-message', {
  connection: { url: config.REDIS_URL },
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 2000, // 2s, 4s, 8s, 16s, 32s
    },
    removeOnComplete: 100,
    removeOnFail: 50,
  },
});

interface MessageJobData {
  threadId: string;
  userMessageId: string;
  agentId: string;
  userId: string;
}

async function processMessageJob(job: Job<MessageJobData>) {
  const { threadId, userMessageId, agentId, userId } = job.data;

  job.log(`Processing message ${userMessageId} for thread ${threadId}`);

  // 1. Fetch the agent
  const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
    return tx.agent.findFirst({
      where: { id: agentId, userId },
    });
  });

  if (!agent) {
    throw new Error(`Agent not found: ${agentId}`);
  }

  // 2. Fetch conversation history (last 20 messages)
  const history = await prisma.$transactionWithUser(userId, async (tx: any) => {
    const messages = await tx.message.findMany({
      where: {
        threadId,
        status: { in: ['sent', 'delivered'] },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return messages.reverse();
  });

  // 3. Create a placeholder agent message with status 'pending'
  const agentMessage = await prisma.$transactionWithUser(userId, async (tx: any) => {
    return tx.message.create({
      data: {
        threadId,
        agentId,
        role: 'agent',
        content: '',
        status: 'pending',
      },
    });
  });

  // Notify clients that agent is typing
  await publishChunk(threadId, {
    type: 'message:status',
    messageId: agentMessage.id,
    status: 'pending',
  });

  // 4. Stream response from connector
  let fullContent = '';

  try {
    const connector = connectorRegistry.get(agent.connectorType);

    // Build config with systemPrompt injected
    const connectorConfig = {
      ...(agent.config as Record<string, unknown>),
      ...(agent.systemPrompt ? { systemPrompt: agent.systemPrompt } : {}),
    };

    const mappedMessages = history.map((msg: any) => ({
      role: msg.role === 'agent' ? 'assistant' : msg.role,
      content: msg.content,
    }));

    const stream = await connector.sendMessage({
      messages: mappedMessages,
      threadId,
      config: connectorConfig,
    });

    for await (const chunk of stream) {
      fullContent += chunk;

      // Publish each chunk for real-time WebSocket delivery
      await publishChunk(threadId, {
        type: 'message:chunk',
        messageId: agentMessage.id,
        chunk,
        fullContent,
      });
    }

    // 5. Update message with final content and mark as delivered
    await prisma.$transactionWithUser(userId, async (tx: any) => {
      await tx.message.update({
        where: { id: agentMessage.id },
        data: {
          content: fullContent,
          status: 'delivered',
          metadata: {
            processingTime: Date.now() - job.timestamp,
            attempt: job.attemptsMade + 1,
          },
        },
      });

      // Update thread timestamp and agent lastUsedAt
      await tx.thread.update({
        where: { id: threadId },
        data: { lastMessageAt: new Date() },
      });

      await tx.agent.update({
        where: { id: agentId },
        data: { lastUsedAt: new Date(), status: 'online' },
      });
    });

    // Notify clients that message is delivered
    await publishChunk(threadId, {
      type: 'message:delivered',
      messageId: agentMessage.id,
      content: fullContent,
    });

    job.log(`Message delivered: ${agentMessage.id} (${fullContent.length} chars)`);
  } catch (err) {
    // Mark message as failed
    const errorMsg = err instanceof ConnectorError
      ? err.message
      : (err as Error).message;

    await prisma.$transactionWithUser(userId, async (tx: any) => {
      await tx.message.update({
        where: { id: agentMessage.id },
        data: {
          content: fullContent || `Error: ${errorMsg}`,
          status: 'failed',
          metadata: {
            error: errorMsg,
            attempt: job.attemptsMade + 1,
          },
        },
      });

      await tx.agent.update({
        where: { id: agentId },
        data: { status: 'error' },
      });
    });

    await publishChunk(threadId, {
      type: 'message:failed',
      messageId: agentMessage.id,
      error: errorMsg,
    });

    // Re-throw so BullMQ retries (if attempts remaining)
    throw err;
  }
}

let worker: Worker | null = null;

/**
 * Start the BullMQ message processing worker.
 */
export function startMessageWorker() {
  worker = new Worker('process-message', processMessageJob, {
    connection: { url: config.REDIS_URL },
    concurrency: 5,
    limiter: {
      max: 10,
      duration: 1000, // 10 jobs per second max
    },
  });

  worker.on('completed', (job) => {
    console.log(`✅ Job ${job.id} completed for thread ${job.data.threadId}`);
  });

  worker.on('failed', (job, err) => {
    console.error(`❌ Job ${job?.id} failed:`, err.message);
  });

  worker.on('error', (err) => {
    console.error('Worker error:', err);
  });

  console.log('🔄 Message worker started (concurrency: 5)');
  return worker;
}

/**
 * Gracefully stop the worker.
 */
export async function stopMessageWorker() {
  if (worker) {
    await worker.close();
    worker = null;
  }
}
