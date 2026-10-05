'use client';

import { useQuery } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { api, type Order } from '@/lib/api';

export function OrderTracker({ orderId }: { orderId: string }) {
  const t = useTranslations('account');
  const { data } = useQuery({
    queryKey: ['order', orderId, 'status'],
    queryFn: () => api.get<Pick<Order, 'status'>>(`/me/orders/${orderId}/status`),
    refetchInterval: 5_000,
    refetchIntervalInBackground: true,
  });

  return <p className="text-sm font-medium">{data ? t(`status.${data.status}`) : '…'}</p>;
}
