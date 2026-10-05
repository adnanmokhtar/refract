'use client';

import { Suspense } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import Link from 'next/link';
import { formatPrice } from '@/lib/format';
import { useCart } from './useCart';

function SummaryBody() {
  const t = useTranslations('cart');
  const th = useTranslations('home');
  const locale = useLocale();
  const { cart } = useCart();

  if (cart.lines.length === 0) {
    return (
      <Link href="/collections/autumn" className="text-sm underline">
        {th('heroCta')}
      </Link>
    );
  }

  return (
    <dl className="flex justify-between text-sm">
      <dt>{t('subtotal')}</dt>
      <dd className="tabular-nums">{formatPrice(cart.subtotal, locale)}</dd>
    </dl>
  );
}

export function CheckoutSummary() {
  const tc = useTranslations('common');
  return (
    <Suspense fallback={<div role="status" aria-label={tc('loading')} className="h-16 animate-pulse rounded-lg bg-muted" />}>
      <SummaryBody />
    </Suspense>
  );
}
