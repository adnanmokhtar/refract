'use client';

import { useRouter } from 'next/navigation';
import { useLocale, useTranslations } from 'next-intl';
import type { Order } from '@/lib/api';

export function OrdersTable({ orders }: { orders: Order[] }) {
  const t = useTranslations('account');
  const locale = useLocale();
  const router = useRouter();
  const money = new Intl.NumberFormat(locale, { style: 'currency', currency: 'USD' });

  return (
    <table className="w-full text-sm">
      <thead>
        <tr>
          <th scope="col" className="py-2 text-start">{t('colOrder')}</th>
          <th scope="col" className="py-2 text-start">{t('colStatus')}</th>
          <th scope="col" className="py-2 text-end">{t('colTotal')}</th>
        </tr>
      </thead>
      <tbody>
        {orders.map((o) => (
          <tr key={o.id} className="cursor-pointer border-t hover:bg-stone-50" onClick={() => router.push(`/account/orders/${o.id}`)}>
            <td className="py-3">{o.number}</td>
            <td className="py-3">{t(`status.${o.status}`)}</td>
            <td className="py-3 text-end tabular-nums">{money.format(o.total / 100)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
