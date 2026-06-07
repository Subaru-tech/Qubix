"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const helmet_1 = __importDefault(require("@fastify/helmet"));
const rate_limit_1 = __importDefault(require("@fastify/rate-limit"));
const config_1 = require("./config");
const client_1 = require("./db/client");
const logger_1 = require("./utils/logger");
const auth_routes_1 = require("./routes/auth.routes");
const fastify = (0, fastify_1.default)({
    logger: logger_1.loggerConfig,
});
// Register log redaction hooks globally
(0, logger_1.registerRedactHooks)(fastify);
const bootstrap = async () => {
    try {
        // 1. CORS plugin (allow mobile origins / all origins in development)
        await fastify.register(cors_1.default, {
            origin: config_1.config.NODE_ENV === 'development' ? true : false,
            methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
            allowedHeaders: ['Content-Type', 'Authorization'],
        });
        // 2. Helmet plugin for security headers
        await fastify.register(helmet_1.default, {
            contentSecurityPolicy: config_1.config.NODE_ENV === 'production',
        });
        // 3. Rate limiting (100 requests per minute per IP)
        await fastify.register(rate_limit_1.default, {
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
                await client_1.prismaClient.$queryRaw `SELECT 1`;
                return {
                    status: 'ok',
                    version: '1.0.0',
                    database: 'connected',
                    timestamp: new Date().toISOString(),
                };
            }
            catch (err) {
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
        await fastify.register(auth_routes_1.authRoutes, { prefix: '/auth' });
        // 7. Listen to incoming requests
        await fastify.listen({ port: config_1.config.PORT, host: '0.0.0.0' });
        fastify.log.info(`Qubix Server successfully started on port ${config_1.config.PORT} under ${config_1.config.NODE_ENV} environment`);
    }
    catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};
// Graceful Shutdown Handler
const handleShutdown = async (signal) => {
    fastify.log.info(`Received ${signal}. Shutting down gracefully...`);
    try {
        await fastify.close();
        await client_1.prismaClient.$disconnect();
        fastify.log.info('Fastify and Prisma clients cleanly disconnected. Exiting.');
        process.exit(0);
    }
    catch (err) {
        fastify.log.error({ err }, 'Error during graceful shutdown');
        process.exit(1);
    }
};
process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));
bootstrap();
