'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { keys, useBasket } from '@/lib/queries';
import { BasketLines } from './BasketLines';
import { BasketSummary } from './BasketSummary';
import { BasketBadge } from './BasketBadge';

export function BasketPanel() {
  const t = useTranslations('cart');
  const qc = useQueryClient();
  const { data, isPending, isError, refetch } = useBasket();
  const remove = useMutation({
    mutationFn: (id: string) => api.del(`/me/basket/lines/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: keys.basket }),
  });

  if (isPending) return <div aria-busy="true" className="h-40 animate-pulse rounded-xl bg-stone-100" />;
  if (isError) {
    return (
      <p role="alert">
        {t('error')}{' '}
        <button type="button" className="underline" onClick={() => refetch()}>
          {t('retry')}
        </button>
      </p>
    );
  }
  if (data.lines.length === 0) return <p>{t('empty')}</p>;

  return (
    <form id="checkout" action="/api/checkout" method="post" className="space-y-4">
      <BasketBadge />
      <BasketLines lines={data.lines} removeLine={(id) => remove.mutate(id)} />
      <BasketSummary lines={data.lines} />
    </form>
  );
}
