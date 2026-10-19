'use client';

import { useTranslations } from 'next-intl';

export function SaleCountdown({ endsAt }: { endsAt: string }) {
  const t = useTranslations('product');
  const minutesLeft = Math.max(0, Math.floor((Date.parse(endsAt) - Date.now()) / 60_000));

  if (minutesLeft === 0) return null;

  return (
    <p className="mt-2 inline-flex rounded-full bg-red-50 px-3 py-1 text-sm text-red-700">
      {t('saleEnds', { minutes: minutesLeft })}
    </p>
  );
}
