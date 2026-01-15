// ============ src/services/validator.ts ============

import Joi from 'joi';
import { ValidationError } from '../utils/errors';
import { ProofRequest } from '../types';

const collateralSchema = Joi.object({
  commitment: Joi.string().required(),
  collateralValue: Joi.string().required(),
  minValue: Joi.string().required(),
  salt: Joi.string().required(),
});

const amountSchema = Joi.object({
  commitment: Joi.string().required(),
  loanAmount: Joi.string().required(),
  minAmount: Joi.string().required(),
  maxAmount: Joi.string().required(),
  salt: Joi.string().required(),
});

const reputationSchema = Joi.object({
  commitment: Joi.string().required(),
  nullifier: Joi.string().required(),
  userScore: Joi.string().required(),
  threshold: Joi.string().required(),
  loanHistory: Joi.array().items(Joi.string()),
  salt: Joi.string().required(),
});

const schemas: Record<string, Joi.ObjectSchema> = {
  collateral: collateralSchema,
  amount: amountSchema,
  reputation: reputationSchema,
};

export class ValidatorService {
  validate(proofType: string, data: any): void {
    const schema = schemas[proofType];
    
    if (!schema) {
      throw new ValidationError(`Unknown proof type: ${proofType}`);
    }

    const { error } = schema.validate(data);
    
    if (error) {
      throw new ValidationError(error.details[0].message);
    }
  }

  validateProofRequest(request: ProofRequest): void {
    if (!request.proofType || !request.inputs) {
      throw new ValidationError('Missing required fields');
    }

    const combinedInputs = {
      ...request.inputs.publicInputs,
      ...request.inputs.privateInputs,
    };

    this.validate(request.proofType, combinedInputs);
  }
}
