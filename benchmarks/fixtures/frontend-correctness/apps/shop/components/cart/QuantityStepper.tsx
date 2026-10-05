'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Minus, Plus } from 'lucide-react';
import { useTranslations } from 'next-intl';
import { api, type BasketLine } from '@/lib/api';
import { keys } from '@/lib/queries';

export function QuantityStepper({ lineId, qty }: { lineId: string; qty: number }) {
  const t = useTranslations('cart');
  const qc = useQueryClient();

  const setQty = useMutation({
    mutationFn: (next: number) => api.patch(`/me/basket/lines/${lineId}`, { qty: next }),
    onMutate: async (next) => {
      await qc.cancelQueries({ queryKey: keys.basket });
      qc.setQueryData<{ lines: BasketLine[] }>(keys.basket, (old) =>
        old ? { lines: old.lines.map((l) => (l.id === lineId ? { ...l, qty: next } : l)) } : old,
      );
    },
    onSettled: () => qc.invalidateQueries({ queryKey: keys.basket }),
  });

  return (
    <div className="flex items-center gap-1">
      <button type="button" aria-label={t('less')} onClick={() => setQty.mutate(qty - 1)} className="grid size-9 place-items-center rounded border">
        <Minus aria-hidden className="size-4" />
      </button>
      <span className="w-6 text-center tabular-nums">{qty}</span>
      <button type="button" aria-label={t('more')} onClick={() => setQty.mutate(qty + 1)} className="grid size-9 place-items-center rounded border">
        <Plus aria-hidden className="size-4" />
      </button>
    </div>
  );
}
