'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { api, ApiError } from '@/lib/api';

export function CouponField() {
  const t = useTranslations('checkout');
  const qc = useQueryClient();
  const [code, setCode] = useState('');

  const apply = useMutation({
    mutationFn: (value: string) => api.post('/me/cart/coupon', { code: value }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['me', 'cart'] });
      toast.success(t('couponApplied'));
    },
    onError: (err) => {
      toast.error(err instanceof ApiError ? err.message : t('coupon'));
    },
  });

  return (
    <form
      className="flex items-end gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        apply.mutate(code);
      }}
    >
      <div className="flex-1">
        <label htmlFor="coupon" className="block text-sm font-medium">
          {t('coupon')}
        </label>
        <input
          id="coupon"
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          className="mt-1 h-11 w-full rounded-lg border px-3 uppercase focus-visible:ring-2 focus-visible:ring-ring"
        />
      </div>
      <button
        type="submit"
        disabled={apply.isPending}
        className="h-11 rounded-lg bg-blue-600 px-4 text-sm font-medium text-primary-foreground focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-50"
      >
        {t('apply')}
      </button>
    </form>
  );
}
