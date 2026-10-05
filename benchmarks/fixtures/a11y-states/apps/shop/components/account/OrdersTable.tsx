'use client';

import Link from 'next/link';
import type { UseQueryResult } from '@tanstack/react-query';
import { useLocale, useTranslations } from 'next-intl';
import { formatDate, formatPrice } from '@/lib/format';
import { ErrorState } from '@/components/ui/ErrorState';
import type { Order } from '@/lib/api';

export function OrdersTable({ query }: { query: UseQueryResult<Order[]> }) {
  const t = useTranslations('account');
  const th = useTranslations('home');
  const locale = useLocale();

  if (query.isPending) {
    return <div aria-busy="true" className="mt-6 h-48 animate-pulse rounded-card bg-muted" />;
  }
  if (query.isError) {
    return <ErrorState onRetry={() => query.refetch()} />;
  }
  if (query.data.length === 0) {
    return (
      <p className="mt-6 text-sm text-muted-foreground">
        <Link href="/collections/autumn" className="underline">
          {th('heroCta')}
        </Link>
      </p>
    );
  }

  return (
    <div className="mt-6 overflow-x-auto rounded-card border">
      <table className="w-full min-w-[40rem] text-sm">
        <caption className="sr-only">{t('orders')}</caption>
        <thead className="bg-muted text-start">
          <tr>
            <th scope="col" className="px-4 py-3 text-start">{t('colNumber')}</th>
            <th scope="col" className="px-4 py-3 text-start">{t('colDate')}</th>
            <th scope="col" className="px-4 py-3 text-end">{t('colTotal')}</th>
            <th scope="col" className="px-4 py-3 text-start">{t('colStatus')}</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {query.data.map((order) => (
            <tr key={order.id}>
              <td className="px-4 py-3">
                <Link href={`/account/orders/${order.id}`} className="underline">
                  {order.number}
                </Link>
              </td>
              <td className="px-4 py-3">{formatDate(order.placedAt, locale)}</td>
              <td className="px-4 py-3 text-end tabular-nums">{formatPrice(order.total, locale)}</td>
              <td className="px-4 py-3">{order.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
