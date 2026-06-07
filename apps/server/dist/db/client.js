"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = exports.prismaClient = void 0;
const client_1 = require("@prisma/client");
const globalForPrisma = global;
exports.prismaClient = globalForPrisma.prisma ??
    new client_1.PrismaClient({
        log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
    });
if (process.env.NODE_ENV !== 'production') {
    globalForPrisma.prisma = exports.prismaClient;
}
exports.prisma = exports.prismaClient.$extends({
    client: {
        /**
         * Executes queries within a transaction block under a specific user context.
         * This sets the PostgreSQL session parameter `app.current_user_id` locally,
         * ensuring Row-Level Security (RLS) policies are correctly evaluated for that user.
         */
        async $transactionWithUser(userId, fn) {
            return exports.prismaClient.$transaction(async (tx) => {
                // Set local transaction-scoped user ID
                await tx.$executeRawUnsafe(`SELECT set_config('app.current_user_id', $1, true);`, userId);
                return fn(tx);
            });
        },
    },
});
