'use client';

import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { useLocale, useTranslations } from 'next-intl';
import { api, type Order } from '@/lib/api';

export function OrderHistory({ customerId }: { customerId: string }) {
  const t = useTranslations('account');
  const locale = useLocale();
  const { data, isPending, isError, refetch } = useQuery({ queryKey: ['orders'], queryFn: () => getOrders(customerId) });

  function OrderRow({ order }: { order: Order }) {
    return (
      <li className="flex justify-between py-3 text-sm">
        <Link href={`/account/orders/${order.id}`}>{order.number}</Link>
        <span>{new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(new Date(order.placedAt))}</span>
      </li>
    );
  }

  if (isPending) return <p aria-busy="true">{t('loading')}</p>;
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
  if (data.length === 0) return <p>{t('noOrders')}</p>;

  return (
    <ul className="divide-y">
      {data.map((order) => (
        <OrderRow key={order.id} order={order} />
      ))}
    </ul>
  );
}

function getOrders(customerId: string) {
  return api.get<Order[]>(`/customers/${customerId}/orders`);
}
