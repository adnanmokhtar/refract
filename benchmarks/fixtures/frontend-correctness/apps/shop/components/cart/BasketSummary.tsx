'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';
import type { BasketLine } from '@/lib/api';

export function BasketSummary({ lines }: { lines: BasketLine[] }) {
  const t = useTranslations('cart');
  const locale = useLocale();
  const [total, setTotal] = useState(0);

  useEffect(() => {
    setTotal(lines.reduce((sum, line) => sum + line.price * line.qty, 0));
  }, [lines]);

  return (
    <dl className="flex justify-between border-t pt-4 text-sm">
      <dt>{t('subtotal')}</dt>
      <dd className="tabular-nums">{new Intl.NumberFormat(locale, { style: 'currency', currency: 'USD' }).format(total / 100)}</dd>
    </dl>
  );
}
