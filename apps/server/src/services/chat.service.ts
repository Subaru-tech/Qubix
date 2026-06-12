import { prisma } from '../db/client';

interface CreateThreadInput {
  agentId: string;
  title?: string;
}

interface CreateMessageInput {
  content: string;
}

export const ChatService = {
  /**
   * List all threads for a user, sorted by lastMessageAt descending.
   * Includes the last message preview (content truncated to 100 chars).
   */
  async listThreads(userId: string) {
    const threads = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findMany({
        where: { userId },
        orderBy: { lastMessageAt: 'desc' },
        include: {
          agent: {
            select: { id: true, name: true, connectorType: true, status: true },
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 1,
            select: { content: true, role: true, createdAt: true },
          },
        },
      });
    });

    return threads.map((thread: any) => {
      const lastMessage = thread.messages[0] || null;
      return {
        id: thread.id,
        title: thread.title,
        agentId: thread.agentId,
        agent: thread.agent,
        isPinned: thread.isPinned,
        lastMessageAt: thread.lastMessageAt,
        createdAt: thread.createdAt,
        lastMessage: lastMessage
          ? {
              content: lastMessage.content.length > 100
                ? lastMessage.content.slice(0, 100) + '…'
                : lastMessage.content,
              role: lastMessage.role,
              createdAt: lastMessage.createdAt,
            }
          : null,
      };
    });
  },

  /**
   * Create a new thread with an active agent.
   */
  async createThread(userId: string, input: CreateThreadInput) {
    // Verify the agent belongs to this user
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: input.agentId, userId },
      });
    });

    if (!agent) {
      throw new Error('Agent not found');
    }

    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.create({
        data: {
          userId,
          agentId: input.agentId,
          title: input.title || `Chat with ${agent.name}`,
        },
        include: {
          agent: {
            select: { id: true, name: true, connectorType: true, status: true },
          },
        },
      });
    });

    return thread;
  },

  /**
   * Get a single thread by ID.
   */
  async getThread(userId: string, threadId: string) {
    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findFirst({
        where: { id: threadId, userId },
        include: {
          agent: {
            select: { id: true, name: true, connectorType: true, status: true },
          },
        },
      });
    });

    return thread;
  },

  /**
   * Get messages for a thread with cursor-based pagination.
   * Returns messages sorted by createdAt descending (newest first).
   */
  async getMessages(userId: string, threadId: string, cursor?: string, limit = 20) {
    // Verify thread ownership
    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findFirst({
        where: { id: threadId, userId },
        select: { id: true },
      });
    });

    if (!thread) return null;

    const messages = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.message.findMany({
        where: { threadId },
        orderBy: { createdAt: 'desc' },
        take: limit + 1, // Fetch one extra to determine if there's a next page
        ...(cursor
          ? {
              cursor: { id: cursor },
              skip: 1, // Skip the cursor itself
            }
          : {}),
        include: {
          agent: {
            select: { id: true, name: true, connectorType: true },
          },
        },
      });
    });

    const hasMore = messages.length > limit;
    const results = hasMore ? messages.slice(0, limit) : messages;
    const nextCursor = hasMore ? results[results.length - 1].id : null;

    return {
      messages: results,
      nextCursor,
      hasMore,
    };
  },

  /**
   * Create a user message in a thread.
   * Returns the created message and the thread's active agent ID for processing.
   */
  async createMessage(userId: string, threadId: string, input: CreateMessageInput) {
    // Verify thread ownership and get active agent
    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findFirst({
        where: { id: threadId, userId },
        select: { id: true, agentId: true },
      });
    });

    if (!thread) return null;

    // Create user message and update thread timestamp in one transaction
    const message = await prisma.$transactionWithUser(userId, async (tx: any) => {
      const msg = await tx.message.create({
        data: {
          threadId,
          role: 'user',
          content: input.content,
          status: 'sent',
        },
      });

      await tx.thread.update({
        where: { id: threadId },
        data: { lastMessageAt: new Date() },
      });

      return msg;
    });

    return {
      message,
      agentId: thread.agentId,
    };
  },

  /**
   * Switch the active agent in a thread. Injects a system message.
   */
  async switchAgent(userId: string, threadId: string, agentId: string) {
    // Verify thread ownership
    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findFirst({
        where: { id: threadId, userId },
        select: { id: true },
      });
    });

    if (!thread) return null;

    // Verify new agent ownership
    const agent = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.agent.findFirst({
        where: { id: agentId, userId },
        select: { id: true, name: true, connectorType: true, status: true },
      });
    });

    if (!agent) {
      throw new Error('Agent not found');
    }

    // Update thread and inject system message
    const updatedThread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      await tx.message.create({
        data: {
          threadId,
          role: 'system',
          content: `Context switched to ${agent.name}`,
          status: 'delivered',
        },
      });

      return tx.thread.update({
        where: { id: threadId },
        data: {
          agentId,
          lastMessageAt: new Date(),
        },
        include: {
          agent: {
            select: { id: true, name: true, connectorType: true, status: true },
          },
        },
      });
    });

    return updatedThread;
  },

  /**
   * Delete a thread and all its messages (cascade).
   */
  async deleteThread(userId: string, threadId: string): Promise<boolean> {
    const thread = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.findFirst({
        where: { id: threadId, userId },
        select: { id: true },
      });
    });

    if (!thread) return false;

    await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.thread.delete({
        where: { id: threadId },
      });
    });

    return true;
  },

  /**
   * Get the conversation history for a thread (for sending to the connector).
   * Returns messages in chronological order (oldest first), limited to last 20.
   */
  async getConversationHistory(userId: string, threadId: string) {
    const messages = await prisma.$transactionWithUser(userId, async (tx: any) => {
      return tx.message.findMany({
        where: {
          threadId,
          role: { in: ['user', 'agent', 'system'] },
          status: { in: ['sent', 'delivered'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 20,
      });
    });

    // Reverse to chronological order
    return messages.reverse();
  },
};
