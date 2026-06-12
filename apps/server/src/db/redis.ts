import Redis from 'ioredis';
import { config } from '../config';

/**
 * Primary Redis client for general-purpose operations (BullMQ, caching, etc.).
 */
export const redis = new Redis(config.REDIS_URL, {
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
export const redisSub = new Redis(config.REDIS_URL, {
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
export const redisPub = new Redis(config.REDIS_URL, {
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
export async function publishChunk(threadId: string, data: Record<string, unknown>) {
  await redisPub.publish(`thread:${threadId}:stream`, JSON.stringify(data));
}

/**
 * Gracefully close all Redis connections.
 */
export async function closeRedis() {
  await Promise.all([
    redis.quit().catch(() => {}),
    redisSub.quit().catch(() => {}),
    redisPub.quit().catch(() => {}),
  ]);
}
