export const PRIVY_APP_ID = process.env.NEXT_PUBLIC_PRIVY_APP_ID || '';

export const MANTLE_SEPOLIA = {
  id: 5003,
  name: 'Mantle Sepolia Testnet',
  network: 'mantle-sepolia',
  nativeCurrency: {
    decimals: 18,
    name: 'Mantle',
    symbol: 'MNT',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.sepolia.mantle.xyz'],
    },
    public: {
      http: ['https://rpc.sepolia.mantle.xyz'],
    },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://explorer.sepolia.mantle.xyz' },
  },
  testnet: true,
};

export const CONTRACTS = {
  LoanCore: '0x7744AfF816C0a785E06CDF7Ce2926A68C03F1117' as `0x${string}`,
  OfferBook: '0x57aa5d9E268C1086c8F3aC7964260D79613c7921' as `0x${string}`,
  CollateralVault: '0x6063B4Aa1406A69e3e6D2671D64e6194031f7487' as `0x${string}`,
  PriceOracle: '0xD58056C9048F483C4a85E49bD7cD7Ec11Ea0281c' as `0x${string}`,
  ReputationRegistry: '0xb078F5cd4e08cDae895faF871bD0E6Fdf8EcfB4E' as `0x${string}`,
  PrivacyModule: '0xD565CC8c8F0C85af46B84cD314b824E64BAFFE10' as `0x${string}`,
  FeeDistributor: '0xF56d05d89f0373b7414D8a6FdBB6f293e7dBDeE7' as `0x${string}`,
  XeroToken: '0x3881DFC77ABFc85b4aDe32D998FA2fd2229F7290' as `0x${string}`,
  Governance: '0xEe5520520b7993a3B7C189Ec9F7F5fD0eFc42CDE' as `0x${string}`,
} as const;

export const TOKENS = {
  USDC: '0x71Fb66498976B7e09fB9FC176Fb1fb53959a4A54' as `0x${string}`,
  DAI: '0x21ab93a1494b1B0E3eafdB24E3703F12F8AfeC20' as `0x${string}`,
  USDT: '0x7B2151392F8428Cf6EA48B6603c1BD6605B02Dbd' as `0x${string}`,
  WETH: '0x216760e96222bCe5DC454a3353364FaD8C088999' as `0x${string}`,
  WBTC: '0x0a468e2506ff15a74c8D094CC09e48561969Aa12' as `0x${string}`,
  LINK: '0x79F319104FEE8e9f2209246eF878aa46deC0bedb' as `0x${string}`,
  MNT: '0x0B680f3E100ce638c77b0fA2761c695E5f87Cc9E' as `0x${string}`,
} as const;

export const TOKEN_DECIMALS: Record<string, number> = {
  [TOKENS.USDC]: 6,
  [TOKENS.DAI]: 18,
  [TOKENS.USDT]: 6,
  [TOKENS.WETH]: 18,
  [TOKENS.WBTC]: 8,
  [TOKENS.LINK]: 18,
  [TOKENS.MNT]: 18,
};

export const TOKEN_SYMBOLS: Record<string, string> = {
  [TOKENS.USDC]: 'USDC',
  [TOKENS.DAI]: 'DAI',
  [TOKENS.USDT]: 'USDT',
  [TOKENS.WETH]: 'WETH',
  [TOKENS.WBTC]: 'WBTC',
  [TOKENS.LINK]: 'LINK',
  [TOKENS.MNT]: 'MNT',
};