// ============ src/routes/proofs.ts ============

import { Router, Request, Response, NextFunction } from 'express';
import { SP1Service } from '../services/sp1';
import { CacheService } from '../services/cache';
import { ValidatorService } from '../services/validator';
import { logger } from '../utils/logger';
import { RateLimitError } from '../utils/errors';
import { config } from '../config';

export function createProofRoutes(
  sp1: SP1Service,
  cache: CacheService,
  validator: ValidatorService
): Router {
  const router = Router();

  // Rate limiting middleware
  const rateLimitMiddleware = async (
    req: Request,
    res: Response,
    next: NextFunction
  ) => {
    const userId = req.headers['x-user-id'] as string || req.ip || 'anonymous';
    const count = await cache.getRateLimit(userId);

    if (count >= config.rateLimit.maxRequests) {
      throw new RateLimitError();
    }

    await cache.incrementRateLimit(userId);
    next();
  };

  router.use(rateLimitMiddleware);

  // Generate proof endpoint
  router.post('/generate', async (req: Request, res: Response) => {
    const { proofType, inputs } = req.body;

    validator.validateProofRequest({ proofType, inputs });

    const combinedInputs = {
      ...inputs.publicInputs,
      ...inputs.privateInputs,
    };

    const inputHash = sp1.hashInputs(combinedInputs);

    // Check cache
    const cached = await cache.getCachedProof(inputHash);
    if (cached) {
      logger.info(`Cache hit for ${proofType} proof`);
      return res.json(JSON.parse(cached));
    }

    // Generate proof
    const result = await sp1.generateProof(proofType, combinedInputs);

    const response = {
      proof: result.proof.toString('hex'),
      publicValues: Array.from(result.publicValues).map(b => b.toString()),
      proofId: inputHash,
      timestamp: Date.now(),
    };

    // Cache result
    await cache.cacheProof(inputHash, JSON.stringify(response), 3600);

    res.json(response);
  });

  // Health check
  router.get('/health', (req: Request, res: Response) => {
    res.json({
      status: 'ok',
      service: config.serviceName,
      timestamp: Date.now(),
    });
  });

  return router;
}
