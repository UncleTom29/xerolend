
// ============ src/types/index.ts ============

export interface ProofRequest {
  proofType: 'collateral' | 'amount' | 'reputation';
  inputs: {
    publicInputs: Record<string, any>;
    privateInputs: Record<string, any>;
  };
  userId?: string;
}

export interface ProofResponse {
  proof: string;
  publicValues: string[];
  proofId: string;
  timestamp: number;
}

export interface SP1ProofResult {
  proof: Uint8Array;
  publicValues: Uint8Array;
}