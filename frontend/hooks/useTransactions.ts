'use client';

import { useState } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { parseUnits, encodeFunctionData } from 'viem';
import { CONTRACTS, TOKENS } from '@/config/wagmi';
import { privacyManager } from '@/utils/privacy';
import LoanCoreABI from '@/abis/LoanCore.json';
import PrivacyModuleABI from '@/abis/PrivacyModule.json';
import ERC20ABI from '@/abis/MockERC20.json';
import { toast } from '@/hooks/use-toast';

export function useTransactions() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { data: walletClient } = useWalletClient();
  const [loading, setLoading] = useState(false);

  async function createLoan(params: {
    principalToken: string;
    principalAmount: string;
    interestRate: number;
    duration: number;
    collateralToken: string;
    collateralAmount: string;
    isPrivate: boolean;
  }) {
    if (!address || !walletClient || !publicClient) {
      toast({ title: 'Error', description: 'Wallet not connected', variant: 'destructive' });
      return;
    }

    setLoading(true);

    try {
      const decimals = params.principalToken === TOKENS.USDC ? 6 : 18;
      const collateralDecimals = params.collateralToken === TOKENS.WETH ? 18 : 18;
      
      const principalAmount = parseUnits(params.principalAmount, decimals);
      const collateralAmount = parseUnits(params.collateralAmount, collateralDecimals);

      // Step 1: Approve collateral
      toast({ title: 'Step 1/3', description: 'Approving collateral...' });
      
      const approveTx = await walletClient.writeContract({
        address: params.collateralToken as `0x${string}`,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [CONTRACTS.CollateralVault, collateralAmount],
      });

      await publicClient.waitForTransactionReceipt({ hash: approveTx });

      let commitment = '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`;

      // Step 2: Generate privacy proof if private
      if (params.isPrivate) {
        toast({ title: 'Step 2/3', description: 'Generating privacy proof...' });

        const salt = privacyManager.generateSalt();
        const proofInputs = privacyManager.prepareLoanAmountProof(
          principalAmount,
          principalAmount * BigInt(80) / BigInt(100), // Min 80% of amount
          principalAmount * BigInt(120) / BigInt(100), // Max 120% of amount
          salt
        );

        commitment = proofInputs.commitment;

        // Request proof from backend
        const proof = await privacyManager.requestProof(
          'amount',
          proofInputs.privateInputs,
          proofInputs.publicInputs
        );

        // Verify proof on-chain
        const formattedProof = privacyManager.formatProofForContract(proof);

        const verifyTx = await walletClient.writeContract({
          address: CONTRACTS.PrivacyModule,
          abi: PrivacyModuleABI,
          functionName: 'verifyGroth16Proof',
          args: [
            commitment,
            formattedProof.a,
            formattedProof.b,
            formattedProof.c,
            formattedProof.publicSignals,
          ],
        });

        await publicClient.waitForTransactionReceipt({ hash: verifyTx });
      }

      // Step 3: Create loan
      toast({ title: 'Step 3/3', description: 'Creating loan...' });

      const createTx = await walletClient.writeContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'createLoan',
        args: [
          params.principalToken,
          principalAmount,
          params.interestRate * 100, // Convert to basis points
          params.duration * 86400, // Convert days to seconds
          0, // ERC20 collateral type
          params.collateralToken,
          BigInt(0), // tokenId (not used for ERC20)
          collateralAmount,
          params.isPrivate,
          commitment,
        ],
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash: createTx });

      toast({ 
        title: 'Success!', 
        description: `Loan created successfully${params.isPrivate ? ' with privacy' : ''}`,
      });

      return receipt;
    } catch (error: any) {
      console.error('Create loan error:', error);
      toast({ 
        title: 'Transaction Failed', 
        description: error.message || 'Failed to create loan',
        variant: 'destructive' 
      });
    } finally {
      setLoading(false);
    }
  }

  async function fundLoan(loanId: number) {
    if (!address || !walletClient || !publicClient) {
      toast({ title: 'Error', description: 'Wallet not connected', variant: 'destructive' });
      return;
    }

    setLoading(true);

    try {
      // Get loan details
      const loan = await publicClient.readContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'getLoan',
        args: [BigInt(loanId)],
      }) as any;

      // Step 1: Approve principal token
      toast({ title: 'Step 1/2', description: 'Approving tokens...' });

      const approveTx = await walletClient.writeContract({
        address: loan.principalToken,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [CONTRACTS.LoanCore, loan.principalAmount],
      });

      await publicClient.waitForTransactionReceipt({ hash: approveTx });

      // Step 2: Fund loan
      toast({ title: 'Step 2/2', description: 'Funding loan...' });

      const fundTx = await walletClient.writeContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'fundLoan',
        args: [BigInt(loanId)],
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash: fundTx });

      toast({ title: 'Success!', description: 'Loan funded successfully' });

      return receipt;
    } catch (error: any) {
      console.error('Fund loan error:', error);
      toast({ 
        title: 'Transaction Failed', 
        description: error.message || 'Failed to fund loan',
        variant: 'destructive' 
      });
    } finally {
      setLoading(false);
    }
  }

  async function repayLoan(loanId: number, amount: string) {
    if (!address || !walletClient || !publicClient) {
      toast({ title: 'Error', description: 'Wallet not connected', variant: 'destructive' });
      return;
    }

    setLoading(true);

    try {
      const loan = await publicClient.readContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'getLoan',
        args: [BigInt(loanId)],
      }) as any;

      const decimals = loan.principalToken === TOKENS.USDC ? 6 : 18;
      const repayAmount = parseUnits(amount, decimals);

      // Step 1: Approve
      toast({ title: 'Step 1/2', description: 'Approving tokens...' });

      const approveTx = await walletClient.writeContract({
        address: loan.principalToken,
        abi: ERC20ABI,
        functionName: 'approve',
        args: [CONTRACTS.LoanCore, repayAmount],
      });

      await publicClient.waitForTransactionReceipt({ hash: approveTx });

      // Step 2: Repay
      toast({ title: 'Step 2/2', description: 'Repaying loan...' });

      const repayTx = await walletClient.writeContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'repayLoan',
        args: [BigInt(loanId), repayAmount],
      });

      const receipt = await publicClient.waitForTransactionReceipt({ hash: repayTx });

      toast({ title: 'Success!', description: 'Loan repaid successfully' });

      return receipt;
    } catch (error: any) {
      console.error('Repay loan error:', error);
      toast({ 
        title: 'Transaction Failed', 
        description: error.message || 'Failed to repay loan',
        variant: 'destructive' 
      });
    } finally {
      setLoading(false);
    }
  }

  return {
    createLoan,
    fundLoan,
    repayLoan,
    loading,
  };
}