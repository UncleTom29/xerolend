// ============ src/services/cache.ts ============

import { createClient, RedisClientType } from 'redis';
import { config } from '../config';
import { logger } from '../utils/logger';

export class CacheService {
  private client: RedisClientType;
  private isConnected: boolean = false;

  constructor() {
    this.client = createClient({
      socket: {
        host: config.redis.host,
        port: config.redis.port,
      },
      password: config.redis.password,
      database: config.redis.db,
    });

    this.client.on('error', (err) => {
      logger.error('Redis Client Error', err);
    });

    this.client.on('connect', () => {
      logger.info('Redis Client Connected');
      this.isConnected = true;
    });
  }

  async connect(): Promise<void> {
    if (!this.isConnected) {
      await this.client.connect();
    }
  }

  async disconnect(): Promise<void> {
    if (this.isConnected) {
      await this.client.disconnect();
      this.isConnected = false;
    }
  }

  async get(key: string): Promise<string | null> {
    try {
      return await this.client.get(key);
    } catch (error) {
      logger.error('Cache get error:', error);
      return null;
    }
  }

  async set(key: string, value: string, ttl: number = 3600): Promise<void> {
    try {
      await this.client.setEx(key, ttl, value);
    } catch (error) {
      logger.error('Cache set error:', error);
    }
  }

  async del(key: string): Promise<void> {
    try {
      await this.client.del(key);
    } catch (error) {
      logger.error('Cache delete error:', error);
    }
  }

  async getRateLimit(userId: string): Promise<number> {
    const key = `ratelimit:${userId}`;
    const count = await this.get(key);
    return count ? parseInt(count) : 0;
  }

  async incrementRateLimit(userId: string): Promise<void> {
    const key = `ratelimit:${userId}`;
    const current = await this.getRateLimit(userId);
    
    if (current === 0) {
      await this.set(key, '1', config.rateLimit.windowMs / 1000);
    } else {
      await this.client.incr(key);
    }
  }

  async getCachedProof(inputHash: string): Promise<string | null> {
    return this.get(`proof:${inputHash}`);
  }

  async cacheProof(inputHash: string, proof: string, ttl: number = 3600): Promise<void> {
    await this.set(`proof:${inputHash}`, proof, ttl);
  }
}