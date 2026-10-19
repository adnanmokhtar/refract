'use client';

import { useLocale, useTranslations } from 'next-intl';
import { useStoreCredit } from '@/lib/queries';
import { api, ApiError } from '@/lib/api';
import { formatPrice } from '@/lib/format';
import { Button } from '@/components/ui/Button';
import { ErrorState } from '@/components/ui/ErrorState';

export function StoreCreditPanel() {
  const t = useTranslations('account');
  const locale = useLocale();
  const { data, error, isPending, refetch } = useStoreCredit();

  if (isPending) return <div aria-busy="true" className="h-24 animate-pulse rounded-card bg-muted" />;

  if (error instanceof ApiError && error.status === 403) {
    return (
      <section className="rounded-card border p-6">
        <h2 className="font-semibold">{t('storeCredit')}</h2>
        <p className="mt-2 text-sm text-muted-foreground">{t('verifyToSee')}</p>
        <Button variant="secondary" className="mt-4" onClick={() => api.post('/me/verify-email', {})}>
          {t('verifyCta')}
        </Button>
      </section>
    );
  }

  if (error) return <ErrorState onRetry={() => refetch()} />;

  return (
    <section className="rounded-card border p-6">
      <h2 className="font-semibold">{t('storeCredit')}</h2>
      <p className="mt-2 text-2xl tabular-nums">{formatPrice(data.balance, locale, data.currency)}</p>
    </section>
  );
}
