'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';
import { api } from '@/lib/api';

export function CouponInput() {
  const t = useTranslations('checkout');
  const [coupon, setCoupon] = useState<string>();
  const [applied, setApplied] = useState(false);

  async function apply() {
    await api.post('/me/basket/coupon', { code: coupon });
    setApplied(true);
  }

  return (
    <div className="flex items-end gap-2">
      <label className="flex-1 text-sm font-medium">
        {t('coupon')}
        <input value={coupon} onChange={(e) => setCoupon(e.target.value)} className="mt-1 h-11 w-full rounded-lg border px-3 uppercase" />
      </label>
      <button type="button" disabled={applied} onClick={apply} className="h-11 rounded-lg border px-4 text-sm">
        {t('apply')}
      </button>
    </div>
  );
}
