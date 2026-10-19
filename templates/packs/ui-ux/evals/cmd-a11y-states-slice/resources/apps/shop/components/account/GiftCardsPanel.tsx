'use client';

import { useLocale, useTranslations } from 'next-intl';
import { useGiftCards } from '@/lib/queries';
import { formatPrice } from '@/lib/format';
import { ErrorState } from '@/components/ui/ErrorState';

export function GiftCardsPanel() {
  const t = useTranslations('account');
  const locale = useLocale();
  const { data, isPending, isError, refetch } = useGiftCards();

  if (isPending) return <div aria-busy="true" className="h-24 animate-pulse rounded-card bg-muted" />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  return (
    <section className="rounded-card border p-6">
      <h2 className="font-semibold">{t('giftCards')}</h2>
      {data.length === 0 ? (
        <p className="mt-2 text-sm text-muted-foreground">—</p>
      ) : (
        <ul className="mt-3 space-y-2 text-sm">
          {data.map((card) => (
            <li key={card.code} className="flex justify-between">
              <span className="font-mono">{card.code}</span>
              <span className="tabular-nums">{formatPrice(card.balance, locale)}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
