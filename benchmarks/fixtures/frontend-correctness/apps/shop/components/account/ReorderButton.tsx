'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';
import { invalidateOrders } from '@/lib/queries';

export function ReorderButton({ orderId }: { orderId: string }) {
  const t = useTranslations('account');
  const qc = useQueryClient();
  const reorder = useMutation({
    mutationFn: () => api.post(`/me/orders/${orderId}/reorder`, {}),
    onSuccess: () => invalidateOrders(qc),
  });

  return (
    <button type="button" disabled={reorder.isPending} onClick={() => reorder.mutate()} className="text-sm underline">
      {t('reorder')}
    </button>
  );
}
