'use client';

import { useState, useEffect } from 'react';
import { createPublicClient, http, formatUnits } from 'viem';
import { CONTRACTS, MANTLE_SEPOLIA } from '@/config/privy';
import LoanCoreABI from '@/abis/LoanCore.json';
import OfferBookABI from '@/abis/OfferBook.json';

const publicClient = createPublicClient({
  chain: MANTLE_SEPOLIA as any,
  transport: http(),
});

export function useMarketStats() {
  const [stats, setStats] = useState({
    totalVolume: '0',
    activeLoans: 0,
    avgAPY: '0',
    privateLoanPercentage: '0',
    availableLiquidity: '0',
    bestRate: '0',
    avgDuration: '0',
    maxLTV: '0',
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  async function fetchStats() {
    try {
      setLoading(true);

      const loanCounter = (await publicClient.readContract({
        address: CONTRACTS.LoanCore,
        abi: LoanCoreABI,
        functionName: 'loanCounter',
      })) as bigint;

      let totalVolume = BigInt(0);
      let activeCount = 0;
      let privateCount = 0;
      let totalAPY = 0;
      let apyCount = 0;
      let totalDuration = 0;

      for (let i = 1; i < Number(loanCounter); i++) {
        try {
          const loan = (await publicClient.readContract({
            address: CONTRACTS.LoanCore,
            abi: LoanCoreABI,
            functionName: 'getLoan',
            args: [BigInt(i)],
          })) as any;

          if (Number(loan.status) <= 1) {
            activeCount++;
            totalVolume += loan.principalAmount;
            
            if (loan.isPrivate) {
              privateCount++;
            }

            totalAPY += Number(loan.interestRate);
            apyCount++;
            totalDuration += Number(loan.duration);
          }
        } catch (err) {
          console.error(`Error fetching loan ${i}:`, err);
        }
      }

      const offerStats = (await publicClient.readContract({
        address: CONTRACTS.OfferBook,
        abi: OfferBookABI,
        functionName: 'getMarketStats',
      })) as any;

      const avgAPY = apyCount > 0 ? (totalAPY / apyCount / 100).toFixed(1) : '0';
      const privatePercentage = activeCount > 0 ? ((privateCount / activeCount) * 100).toFixed(0) : '0';
      const avgDur = apyCount > 0 ? Math.floor(totalDuration / apyCount / 86400) : 0;

      setStats({
        totalVolume: formatUnits(totalVolume, 6),
        activeLoans: activeCount || Number(offerStats.activeOffers) || 0,
        avgAPY: avgAPY,
        privateLoanPercentage: privatePercentage,
        availableLiquidity: formatUnits(totalVolume / BigInt(2), 6),
        bestRate: avgAPY ? (Number(avgAPY) - 2).toFixed(1) : '7.2',
        avgDuration: avgDur > 0 ? `${avgDur}d` : '45d',
        maxLTV: '75',
      });
    } catch (error) {
      console.error('Error fetching market stats:', error);
      setStats({
        totalVolume: '0',
        activeLoans: 0,
        avgAPY: '0',
        privateLoanPercentage: '0',
        availableLiquidity: '0',
        bestRate: '0',
        avgDuration: '0d',
        maxLTV: '0',
      });
    } finally {
      setLoading(false);
    }
  }

  return { stats, loading, refetch: fetchStats };
}