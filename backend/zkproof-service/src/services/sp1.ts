// ============ src/services/sp1.ts ============

import { spawn } from 'child_process';
import crypto from 'crypto';
import { config } from '../config';
import { logger } from '../utils/logger';
import { ProofGenerationError } from '../utils/errors';
import { SP1ProofResult } from '../types';

export class SP1Service {
  private programPaths = config.sp1.programPaths;

  async generateProof(
    proofType: 'collateral' | 'amount' | 'reputation',
    inputs: Record<string, any>
  ): Promise<SP1ProofResult> {
    const programPath = this.programPaths[proofType];
    
    if (!programPath) {
      throw new ProofGenerationError(`No program found for type: ${proofType}`);
    }

    logger.info(`Generating ${proofType} proof with SP1`);
    const startTime = Date.now();

    try {
      const inputJson = JSON.stringify(inputs);
      const proof = await this.executeProgram(programPath, inputJson);
      
      const duration = Date.now() - startTime;
      logger.info(`${proofType} proof generated in ${duration}ms`);

      return proof;
    } catch (error) {
      logger.error(`SP1 proof generation failed:`, error);
      throw new ProofGenerationError(`Failed to generate ${proofType} proof`);
    }
  }

  private executeProgram(programPath: string, input: string): Promise<SP1ProofResult> {
    return new Promise((resolve, reject) => {
      const child = spawn(programPath, [], {
        env: {
          ...process.env,
          SP1_PROVER: 'network',
          SP1_PRIVATE_KEY: process.env.SP1_PRIVATE_KEY,
        },
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
        logger.debug(`SP1 stderr: ${data}`);
      });

      child.stdin.write(input);
      child.stdin.end();

      child.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`SP1 program exited with code ${code}: ${stderr}`));
          return;
        }

        try {
          const result = JSON.parse(stdout);
          resolve({
            proof: Buffer.from(result.proof, 'hex'),
            publicValues: Buffer.from(result.public_values, 'hex'),
          });
        } catch (error) {
          reject(new Error(`Failed to parse SP1 output: ${error}`));
        }
      });

      child.on('error', (error) => {
        reject(error);
      });
    });
  }

  hashInputs(inputs: Record<string, any>): string {
    const str = JSON.stringify(inputs, Object.keys(inputs).sort());
    return crypto.createHash('sha256').update(str).digest('hex');
  }
}
