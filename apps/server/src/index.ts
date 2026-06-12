import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { config } from './config';
import { prismaClient } from './db/client';
import { redis, closeRedis } from './db/redis';
import { loggerConfig, registerRedactHooks } from './utils/logger';
import { authRoutes } from './routes/auth.routes';
import { agentRoutes } from './routes/agent.routes';
import { chatRoutes } from './routes/chat.routes';
import { websocketPlugin } from './plugins/websocket';
import { startMessageWorker, stopMessageWorker, messageQueue } from './workers/message.worker';

const fastify = Fastify({
  logger: loggerConfig,
});

// Register log redaction hooks globally
registerRedactHooks(fastify);

const bootstrap = async () => {
  try {
    // 1. CORS plugin (allow mobile origins / all origins in development)
    await fastify.register(cors, {
      origin: config.NODE_ENV === 'development' ? true : false,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    });

    // 2. Helmet plugin for security headers
    await fastify.register(helmet, {
      contentSecurityPolicy: config.NODE_ENV === 'production',
    });

    // 3. Rate limiting (100 requests per minute per IP)
    await fastify.register(rateLimit, {
      max: 100,
      timeWindow: '1 minute',
    });

    // 4. WebSocket plugin (must register before routes)
    await fastify.register(websocketPlugin);

    // 5. Default root route
    fastify.get('/', async (request, reply) => {
      return { status: 'ok', message: 'Qubix API is running' };
    });

    // 6. Enhanced health check endpoint
    fastify.get('/health', async (request, reply) => {
      try {
        // Ping PostgreSQL
        await prismaClient.$queryRaw`SELECT 1`;

        // Ping Redis
        const redisPing = await redis.ping();

        return {
          status: 'ok',
          version: '1.0.0',
          database: 'connected',
          redis: redisPing === 'PONG' ? 'connected' : 'error',
          timestamp: new Date().toISOString(),
        };
      } catch (err) {
        request.log.error({ err }, 'Health check failed');
        return reply.status(500).send({
          status: 'error',
          version: '1.0.0',
          database: 'unknown',
          redis: 'unknown',
          timestamp: new Date().toISOString(),
        });
      }
    });

    // 7. Register Routes
    await fastify.register(authRoutes, { prefix: '/auth' });
    await fastify.register(agentRoutes, { prefix: '/agents' });
    await fastify.register(chatRoutes, { prefix: '/threads' });

    // 8. Start BullMQ message processing worker
    startMessageWorker();

    // 9. Listen to incoming requests
    await fastify.listen({ port: config.PORT, host: '0.0.0.0' });
    fastify.log.info(
      `Qubix Server successfully started on port ${config.PORT} under ${config.NODE_ENV} environment`
    );
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

// Graceful Shutdown Handler
const handleShutdown = async (signal: string) => {
  fastify.log.info(`Received ${signal}. Shutting down gracefully...`);
  try {
    await stopMessageWorker();
    await messageQueue.close();
    await fastify.close();
    await prismaClient.$disconnect();
    await closeRedis();
    fastify.log.info('All connections cleanly closed. Exiting.');
    process.exit(0);
  } catch (err) {
    fastify.log.error({ err }, 'Error during graceful shutdown');
    process.exit(1);
  }
};

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

bootstrap();
