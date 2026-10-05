'use client';

import { useEffect, useState } from 'react';
import { useLocale, useTranslations } from 'next-intl';

// The next delivery window depends on the visitor's clock, so it is computed after hydration.
export function DeliveryEta() {
  const t = useTranslations('product');
  const locale = useLocale();
  const [eta, setEta] = useState<string | null>(null);

  useEffect(() => {
    const now = new Date();
    const next = new Date(now.getTime() + (now.getHours() < 14 ? 4 : 20) * 3_600_000);
    setEta(new Intl.DateTimeFormat(locale, { weekday: 'long', hour: 'numeric' }).format(next));
  }, [locale]);

  return <p className="mt-2 text-sm text-stone-600">{eta ? t('eta', { when: eta }) : ' '}</p>;
}
