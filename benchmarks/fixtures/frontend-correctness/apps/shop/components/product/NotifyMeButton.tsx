'use client';

import { useState } from 'react';
import { useTranslations } from 'next-intl';

export function NotifyMeButton({ productId }: { productId: string }) {
  const t = useTranslations('product');
  const [done, setDone] = useState(false);

  return (
    <button
      type="button"
      disabled={done}
      onClick={async () => {
        await fetch('/api/stock-alerts', { method: 'POST', body: JSON.stringify({ productId }) });
        setDone(true);
      }}
      className="mt-4 h-11 rounded-lg border px-4 text-sm disabled:opacity-60"
    >
      {done ? t('notifyDone') : t('notifyMe')}
    </button>
  );
}
