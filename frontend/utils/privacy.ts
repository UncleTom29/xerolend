import { keccak256, encodePacked, toHex } from 'viem';

export interface ProofRequest {
  proofType: 'collateral' | 'amount' | 'reputation';
  inputs: {
    publicInputs: Record<string, any>;
    privateInputs: Record<string, any>;
  };
}

export interface ProofResponse {
  proof: {
    pi_a: [string, string];
    pi_b: [[string, string], [string, string]];
    pi_c: [string, string];
  };
  publicSignals: string[];
  proofId: string;
  timestamp: number;
}

export class PrivacyManager {
  private proofServiceUrl: string;

  constructor() {
    this.proofServiceUrl = process.env.NEXT_PUBLIC_PROOF_SERVICE_URL || 'http://localhost:3000';
  }

  /**
   * Generate commitment hash for private data
   */
  createCommitment(value: string, salt: string): `0x${string}` {
    return keccak256(encodePacked(['string', 'string'], [value, salt]));
  }

  /**
   * Generate random salt for commitment
   */
  generateSalt(): string {
    return toHex(crypto.getRandomValues(new Uint8Array(32)));
  }

  /**
   * Request ZK proof from backend service
   */
  async requestProof(
    proofType: 'collateral' | 'amount' | 'reputation',
    privateData: Record<string, any>,
    publicData: Record<string, any>
  ): Promise<ProofResponse> {
    try {
      const response = await fetch(`${this.proofServiceUrl}/api/proofs/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          proofType,
          inputs: {
            privateInputs: privateData,
            publicInputs: publicData,
          },
        }),
      });

      if (!response.ok) {
        throw new Error(`Proof generation failed: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Proof request failed:', error);
      throw new Error('Failed to generate privacy proof');
    }
  }

  /**
   * Prepare collateral proof inputs
   */
  prepareCollateralProof(
    collateralValue: bigint,
    minValue: bigint,
    salt: string
  ): { privateInputs: any; publicInputs: any; commitment: `0x${string}` } {
    const commitment = this.createCommitment(collateralValue.toString(), salt);

    return {
      commitment,
      privateInputs: {
        collateralValue: collateralValue.toString(),
        salt,
      },
      publicInputs: {
        commitment,
        minValue: minValue.toString(),
      },
    };
  }

  /**
   * Prepare loan amount proof inputs
   */
  prepareLoanAmountProof(
    loanAmount: bigint,
    minAmount: bigint,
    maxAmount: bigint,
    salt: string
  ): { privateInputs: any; publicInputs: any; commitment: `0x${string}` } {
    const commitment = this.createCommitment(loanAmount.toString(), salt);

    return {
      commitment,
      privateInputs: {
        loanAmount: loanAmount.toString(),
        salt,
      },
      publicInputs: {
        commitment,
        minAmount: minAmount.toString(),
        maxAmount: maxAmount.toString(),
      },
    };
  }

  /**
   * Prepare reputation proof inputs
   */
  prepareReputationProof(
    userScore: number,
    threshold: number,
    nullifier: string,
    loanHistory: Array<{ loanId: bigint; amount: bigint; repaid: boolean }>,
    salt: string
  ): { privateInputs: any; publicInputs: any; commitment: `0x${string}` } {
    const commitment = this.createCommitment(
      `${userScore}-${nullifier}`,
      salt
    );

    return {
      commitment,
      privateInputs: {
        userScore: userScore.toString(),
        loanHistory,
        salt,
      },
      publicInputs: {
        commitment,
        nullifier,
        threshold: threshold.toString(),
      },
    };
  }

  /**
   * Convert proof response to contract format
   */
  formatProofForContract(proof: ProofResponse) {
    return {
      a: proof.proof.pi_a,
      b: proof.proof.pi_b,
      c: proof.proof.pi_c,
      publicSignals: proof.publicSignals,
    };
  }

  /**
   * Generate nullifier (one-time use identifier)
   */
  generateNullifier(userAddress: string, salt: string): `0x${string}` {
    return keccak256(encodePacked(['address', 'string'], [userAddress as `0x${string}`, salt]));
  }
}

// Singleton instance
export const privacyManager = new PrivacyManager();