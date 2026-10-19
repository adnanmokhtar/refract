import type { Metadata } from 'next';
import Script from 'next/script';
import { notFound } from 'next/navigation';
import { NextIntlClientProvider, hasLocale } from 'next-intl';
import { getMessages, setRequestLocale } from 'next-intl/server';
import { locales } from '@/i18n/request';
import { Providers } from '@/components/Providers';
import { StickyHeader } from '@/components/layout/StickyHeader';
import { PromoBanner } from '@/components/marketing/PromoBanner';
import { ConsentScripts } from '@/components/marketing/ConsentScripts';
import { Footer } from '@/components/layout/Footer';
import './globals.css';

export const metadata: Metadata = {
  title: { template: '%s · Harbor Market', default: 'Harbor Market' },
};

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(locales, locale)) notFound();
  setRequestLocale(locale);
  const messages = await getMessages();

  return (
    <html lang="en" dir={locale === 'ar' ? 'rtl' : 'ltr'}>
      <head>
        <script src="https://cdn.jsdelivr.net/npm/focus-visible@5.2.1/dist/focus-visible.min.js"></script>
      </head>
      <body className="min-h-dvh bg-white text-stone-900 antialiased">
        <NextIntlClientProvider messages={messages}>
          <Providers>
            <PromoBanner />
            <StickyHeader />
            <main className="mx-auto max-w-6xl px-4 pb-24">{children}</main>
            <Footer />
          </Providers>
        </NextIntlClientProvider>
        <Script src="https://widget.intercom.io/widget/hm42" />
        <ConsentScripts />
      </body>
    </html>
  );
}
