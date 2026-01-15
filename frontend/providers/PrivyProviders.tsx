'use client';

import { PrivyProvider } from '@privy-io/react-auth';
import { WagmiProvider, createConfig, http } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { PRIVY_APP_ID, MANTLE_SEPOLIA } from '@/config/privy';
import { Toaster } from '@/components/ui/toaster';

const queryClient = new QueryClient();

const wagmiConfig = createConfig({
  chains: [MANTLE_SEPOLIA as any],
  transports: {
    [MANTLE_SEPOLIA.id]: http(),
  },
});

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <PrivyProvider
      appId={PRIVY_APP_ID}
      config={{
        appearance: {
          theme: 'dark',
          accentColor: '#00ff87',
          logo: './favicon.ico',
        },
        loginMethods: ['wallet', 'email', 'sms'],
        embeddedWallets: {
          ethereum: {
            createOnLogin: 'users-without-wallets',
          },
        },
        defaultChain: MANTLE_SEPOLIA as any,
        supportedChains: [MANTLE_SEPOLIA as any],
      }}
    >
      <QueryClientProvider client={queryClient}>
        <WagmiProvider config={wagmiConfig}>
          {children}
          <Toaster />
        </WagmiProvider>
      </QueryClientProvider>
    </PrivyProvider>
  );
}