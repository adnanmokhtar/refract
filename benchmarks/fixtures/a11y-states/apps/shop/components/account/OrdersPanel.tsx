'use client';

import { useTranslations } from 'next-intl';
import { useOrders } from '@/lib/queries';
import { OrdersTable } from './OrdersTable';

export function OrdersPanel() {
  const t = useTranslations('account');
  const orders = useOrders();

  return (
    <section aria-labelledby="orders-title">
      <h1 id="orders-title" className="text-2xl font-semibold">
        {t('orders')}
      </h1>
      <OrdersTable query={orders} />
    </section>
  );
}
