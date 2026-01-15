// ============ src/server.ts ============

import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { SP1Service } from './services/sp1';
import { CacheService } from './services/cache';
import { ValidatorService } from './services/validator';
import { createProofRoutes } from './routes/proofs';
import { logger } from './utils/logger';
import { AppError } from './utils/errors';
import { config } from './config';

export function createServer(): Express {
  const app = express();

  // Services
  const sp1 = new SP1Service();
  const cache = new CacheService();
  const validator = new ValidatorService();

  // Middleware
  app.use(cors());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Request logging
  app.use((req: Request, res: Response, next: NextFunction) => {
    logger.info(`${req.method} ${req.path}`, {
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
    next();
  });

  // Routes
  app.use('/api/proofs', createProofRoutes(sp1, cache, validator));

  // 404 handler
  app.use((req: Request, res: Response) => {
    res.status(404).json({ error: 'Route not found' });
  });

  // Error handler
  app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
    if (err instanceof AppError) {
      logger.error(`AppError: ${err.message}`, { statusCode: err.statusCode });
      return res.status(err.statusCode).json({
        error: err.message,
        statusCode: err.statusCode,
      });
    }

    logger.error('Unhandled error:', err);
    res.status(500).json({
      error: 'Internal server error',
      message: config.env === 'development' ? err.message : undefined,
    });
  });

  // Store cache instance for cleanup
  (app as any).cache = cache;

  return app;
}