import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { config } from './config';
import { prismaClient } from './db/client';
import { loggerConfig, registerRedactHooks } from './utils/logger';
import { authRoutes } from './routes/auth.routes';

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

    // 4. Default root route
    fastify.get('/', async (request, reply) => {
      return { status: 'ok', message: 'Qubix API is running' };
    });

    // 5. Enhanced health check endpoint
    fastify.get('/health', async (request, reply) => {
      try {
        // Ping PostgreSQL using the main Prisma client instance
        await prismaClient.$queryRaw`SELECT 1`;
        return {
          status: 'ok',
          version: '1.0.0',
          database: 'connected',
          timestamp: new Date().toISOString(),
        };
      } catch (err) {
        request.log.error({ err }, 'Health check failed: Database connection is down');
        return reply.status(500).send({
          status: 'error',
          version: '1.0.0',
          database: 'disconnected',
          timestamp: new Date().toISOString(),
        });
      }
    });

    // 6. Register Authentication Routes
    await fastify.register(authRoutes, { prefix: '/auth' });

    // 7. Listen to incoming requests
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
    await fastify.close();
    await prismaClient.$disconnect();
    fastify.log.info('Fastify and Prisma clients cleanly disconnected. Exiting.');
    process.exit(0);
  } catch (err) {
    fastify.log.error({ err }, 'Error during graceful shutdown');
    process.exit(1);
  }
};

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

bootstrap();
