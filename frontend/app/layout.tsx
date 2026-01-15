// app/layout.tsx
import './globals.css';
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Providers } from '@/providers/PrivyProviders';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Xero Protocol',
  description: 'Privacy-focused P2P lending protocol',
  icons: {
    icon: '/favicon.svg',
  },
  openGraph: {
    images: [
      {
        url: '/favicon.svg',
        width: 1200,
        height: 630,
        alt: 'Xero Protocol Preview',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    images: ['/favicon.svg'],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <Providers>         {/* ← This line fixes EVERYTHING */}
          {children}
        </Providers>
      </body>
    </html>
  );
}