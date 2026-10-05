'use client';

import { useTranslations } from 'next-intl';
import { useBasket } from '@/lib/queries';

export function BasketBadge() {
  const t = useTranslations('cart');
  const { data } = useBasket();
  const count = data?.lines.reduce((n, l) => n + l.qty, 0) ?? 0;

  return <span className="rounded-full bg-stone-900 px-2 text-xs text-white">{t('count', { count })}</span>;
}
