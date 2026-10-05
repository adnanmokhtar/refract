'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { api } from '@/lib/api';
import { Button } from '@/components/ui/Button';

export function AddToCart({ productId }: { productId: string }) {
  const t = useTranslations('product');
  const qc = useQueryClient();
  const add = useMutation({
    mutationFn: () => api.post('/me/cart/lines', { productId, qty: 1 }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['me', 'cart'] });
      toast.success(t('addToCart'));
    },
  });

  return (
    <Button className="mt-6 w-full" disabled={add.isPending} busy={add.isPending} onClick={() => add.mutate()}>
      {t('addToCart')}
    </Button>
  );
}
