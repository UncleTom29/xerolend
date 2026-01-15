'use client';

import { useState, useEffect } from 'react';
import { createPublicClient, http, formatUnits } from 'viem';
import { CONTRACTS, TOKEN_DECIMALS, TOKEN_SYMBOLS, MANTLE_SEPOLIA } from '@/config/privy';
import LoanCoreABI from '@/abis/LoanCore.json';

export interface Loan {
  id: number;
  type: 'borrow' | 'lend';
  amount: string;
  collateral: string;
  apy: string;
  duration: string;
  ltv: string;
  private: boolean;
  status: string;
  borrower: string;
  lender: string;
  principalToken: string;
  collateralType: number;
}

const publicClient = createPublicClient({
  chain: MANTLE_SEPOLIA as any,
  transport: http(),
});

export function useLoans() {
  const [loans, setLoans] = useState<Loan[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchLoans();
  }, []);

  async function fetchLoans() {
    try {
      setLoading(true);

      const loanCounter = await publicClient.readContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'loanCounter',
      }) as bigint;

      const fetchedLoans: Loan[] = [];

      for (let i = 1; i < Number(loanCounter); i++) {
        try {
          const loan = await publicClient.readContract({
            address: CONTRACTS.LoanCore,
            abi: LoanCoreABI,
            functionName: 'getLoan',
            args: [BigInt(i)],
          }) as any;

          if (Number(loan.status) >= 3) continue;

          const collateral = await publicClient.readContract({
            address: CONTRACTS.LoanCore,
            abi: LoanCoreABI,
            functionName: 'getCollateral',
            args: [loan.collateralId],
          }) as any;

          const tokenDecimals = TOKEN_DECIMALS[loan.principalToken as string] || 6;
          const formattedAmount = formatUnits(loan.principalAmount, tokenDecimals);
          const principalSymbol = TOKEN_SYMBOLS[loan.principalToken as string] || 'Unknown';

          fetchedLoans.push({
            id: Number(loan.loanId),
            type: loan.lender === '0x0000000000000000000000000000000000000000' ? 'borrow' : 'lend',
            amount: loan.isPrivate ? '****** ' + principalSymbol : `${formattedAmount} ${principalSymbol}`,
            collateral: loan.isPrivate ? 'Hidden' : formatCollateral(collateral),
            apy: loan.isPrivate ? '****' : `${Number(loan.interestRate) / 100}%`,
            duration: loan.isPrivate ? '*** days' : `${Math.floor(Number(loan.duration) / 86400)} days`,
            ltv: loan.isPrivate ? '***' : '65%',
            private: loan.isPrivate,
            status: getStatusString(Number(loan.status)),
            borrower: loan.borrower,
            lender: loan.lender,
            principalToken: loan.principalToken,
            collateralType: Number(collateral.collateralType),
          });
        } catch (err) {
          console.error(`Error fetching loan ${i}:`, err);
        }
      }

      setLoans(fetchedLoans);
    } catch (error) {
      console.error('Error fetching loans:', error);
    } finally {
      setLoading(false);
    }
  }

  return { loans, loading, refetch: fetchLoans };
}

function formatCollateral(collateral: any): string {
  if (collateral.collateralType === 0) {
    const decimals = TOKEN_DECIMALS[collateral.assetAddress as string] || 18;
    const amount = formatUnits(collateral.amount, decimals);
    const symbol = TOKEN_SYMBOLS[collateral.assetAddress as string] || 'Unknown';
    return `${amount} ${symbol}`;
  } else if (collateral.collateralType === 1) {
    return `NFT #${collateral.tokenId}`;
  } else if (collateral.collateralType === 3) {
    return 'Asset Bundle';
  }
  return 'Unknown';
}

function getStatusString(status: number): string {
  const statuses = ['Created', 'Active', 'Repaid', 'Defaulted', 'Cancelled'];
  return statuses[status] || 'Unknown';
}