'use client';

import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { mantleSepoliaTestnet } from '@mantleio/viem/chains';

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || '';

export const config = getDefaultConfig({
  appName: 'Xero Protocol',
  projectId,
  chains: [mantleSepoliaTestnet],
  ssr: true,
});

export const CONTRACTS = {
  LoanCore: process.env.NEXT_PUBLIC_LOAN_CORE_ADDRESS as `0x${string}`,
  OfferBook: process.env.NEXT_PUBLIC_OFFER_BOOK_ADDRESS as `0x${string}`,
  CollateralVault: process.env.NEXT_PUBLIC_COLLATERAL_VAULT_ADDRESS as `0x${string}`,
  PriceOracle: process.env.NEXT_PUBLIC_PRICE_ORACLE_ADDRESS as `0x${string}`,
  ReputationRegistry: process.env.NEXT_PUBLIC_REPUTATION_REGISTRY_ADDRESS as `0x${string}`,
  PrivacyModule: process.env.NEXT_PUBLIC_PRIVACY_MODULE_ADDRESS as `0x${string}`,
  FeeDistributor: process.env.NEXT_PUBLIC_FEE_DISTRIBUTOR_ADDRESS as `0x${string}`,
  XeroToken: process.env.NEXT_PUBLIC_XERO_TOKEN_ADDRESS as `0x${string}`,
  Governance: process.env.NEXT_PUBLIC_GOVERNANCE_ADDRESS as `0x${string}`,
} as const;

export const TOKENS = {
  USDC: process.env.NEXT_PUBLIC_USDC_ADDRESS as `0x${string}`,
  DAI: process.env.NEXT_PUBLIC_DAI_ADDRESS as `0x${string}`,
  USDT: process.env.NEXT_PUBLIC_USDT_ADDRESS as `0x${string}`,
  WETH: process.env.NEXT_PUBLIC_WETH_ADDRESS as `0x${string}`,
  WBTC: process.env.NEXT_PUBLIC_WBTC_ADDRESS as `0x${string}`,
  LINK: process.env.NEXT_PUBLIC_LINK_ADDRESS as `0x${string}`,
} as const;

export const TOKEN_DECIMALS: Record<string, number> = {
  [TOKENS.USDC]: 6,
  [TOKENS.DAI]: 18,
  [TOKENS.USDT]: 6,
  [TOKENS.WETH]: 18,
  [TOKENS.WBTC]: 8,
  [TOKENS.LINK]: 18,
};

export const TOKEN_SYMBOLS: Record<string, string> = {
  [TOKENS.USDC]: 'USDC',
  [TOKENS.DAI]: 'DAI',
  [TOKENS.USDT]: 'USDT',
  [TOKENS.WETH]: 'WETH',
  [TOKENS.WBTC]: 'WBTC',
  [TOKENS.LINK]: 'LINK',
};