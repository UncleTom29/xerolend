// ============ src/config.ts ============

import dotenv from 'dotenv';
import path from 'path';

const env = process.env.NODE_ENV || 'development';
dotenv.config({ path: path.resolve(process.cwd(), `.env.${env}`) });

export const config = {
  env,
  port: parseInt(process.env.PORT || '3000'),
  serviceName: process.env.SERVICE_NAME || 'proof-service',
  
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
    password: process.env.REDIS_PASSWORD,
    db: parseInt(process.env.REDIS_DB || '0'),
  },
  
  sp1: {
    proverUrl: process.env.SP1_PROVER_URL || 'http://localhost:3001',
    rpcUrl: process.env.SP1_RPC_URL || 'https://rpc.succinct.xyz/',
    programPaths: {
      collateral: path.resolve(__dirname, '../sp1-programs/collateral-value/target/release/collateral-value'),
      amount: path.resolve(__dirname, '../sp1-programs/loan-amount/target/release/loan-amount'),
      reputation: path.resolve(__dirname, '../sp1-programs/reputation/target/release/reputation'),
    },
  },
  
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW || '3600') * 1000,
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  },
  
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || './logs/proof-service.log',
  },
  
  aws: {
    region: process.env.AWS_REGION || 'us-east-1',
    s3Bucket: process.env.AWS_S3_BUCKET || 'xero-proofs',
    cloudWatchGroup: process.env.AWS_CLOUDWATCH_GROUP || '/xero/proof-service',
  },
};