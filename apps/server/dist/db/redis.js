"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redisPub = exports.redisSub = exports.redis = void 0;
exports.publishChunk = publishChunk;
exports.closeRedis = closeRedis;
const ioredis_1 = __importDefault(require("ioredis"));
const config_1 = require("../config");
/**
 * Primary Redis client for general-purpose operations (BullMQ, caching, etc.).
 */
exports.redis = new ioredis_1.default(config_1.config.REDIS_URL, {
    maxRetriesPerRequest: null, // Required by BullMQ
    enableReadyCheck: false,
    retryStrategy(times) {
        const delay = Math.min(times * 200, 5000);
        return delay;
    },
});
/**
 * Dedicated Redis client for Pub/Sub subscriptions.
 * Pub/Sub requires a separate connection because once a client enters
 * subscriber mode, it can't issue regular commands.
 */
exports.redisSub = new ioredis_1.default(config_1.config.REDIS_URL, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    retryStrategy(times) {
        const delay = Math.min(times * 200, 5000);
        return delay;
    },
});
/**
 * Dedicated Redis client for Pub/Sub publishing.
 */
exports.redisPub = new ioredis_1.default(config_1.config.REDIS_URL, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    retryStrategy(times) {
        const delay = Math.min(times * 200, 5000);
        return delay;
    },
});
/**
 * Publish a message chunk to the thread's streaming channel.
 */
async function publishChunk(threadId, data) {
    await exports.redisPub.publish(`thread:${threadId}:stream`, JSON.stringify(data));
}
/**
 * Gracefully close all Redis connections.
 */
async function closeRedis() {
    await Promise.all([
        exports.redis.quit().catch(() => { }),
        exports.redisSub.quit().catch(() => { }),
        exports.redisPub.quit().catch(() => { }),
    ]);
}
