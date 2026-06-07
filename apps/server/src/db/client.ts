import { PrismaClient } from '@prisma/client';

const globalForPrisma = global as unknown as { prisma: PrismaClient | undefined };

export const prismaClient =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prismaClient;
}

export const prisma = prismaClient.$extends({
  client: {
    /**
     * Executes queries within a transaction block under a specific user context.
     * This sets the PostgreSQL session parameter `app.current_user_id` locally,
     * ensuring Row-Level Security (RLS) policies are correctly evaluated for that user.
     */
    async $transactionWithUser<T>(
      userId: string,
      fn: (tx: any) => Promise<T>
    ): Promise<T> {
      return prismaClient.$transaction(async (tx: any) => {
        // Set local transaction-scoped user ID
        await tx.$executeRawUnsafe(
          `SELECT set_config('app.current_user_id', $1, true);`,
          userId
        );
        return fn(tx);
      });
    },
  },
});

export type ExtendedPrismaClient = typeof prisma;
