import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  weight: ['300', '400', '500', '600', '700', '800', '900'],
});

export const metadata: Metadata = {
  title: 'Agrimore – From Farm to Your Doorstep',
  description:
    'Connect with local farmers & sellers. Fresh products, fair prices, no middlemen. Now serving Theni District.',
  keywords: [
    'Agrimore',
    'farm fresh',
    'organic',
    'vegetables',
    'fruits',
    'Theni',
    'marketplace',
    'farmers',
    'delivery',
  ],
  openGraph: {
    title: 'Agrimore – From Farm to Your Doorstep',
    description:
      'Connect with local farmers & sellers. Fresh products, fair prices, no middlemen.',
    type: 'website',
    locale: 'en_IN',
    siteName: 'Agrimore',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}
