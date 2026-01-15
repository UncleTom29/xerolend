// ============ src/index.ts ============

import { createServer } from './server';
import { config } from './config';
import { logger } from './utils/logger';

async function start() {
  try {
    const app = createServer();
    const cache = (app as any).cache;

    // Connect to Redis
    await cache.connect();

    const server = app.listen(config.port, () => {
      logger.info(`${config.serviceName} running on port ${config.port}`);
      logger.info(`Environment: ${config.env}`);
    });

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      logger.info('SIGTERM received, shutting down gracefully');
      server.close(async () => {
        await cache.disconnect();
        process.exit(0);
      });
    });

  } catch (error) {
    logger.error('Failed to start service:', error);
    process.exit(1);
  }
}

start();