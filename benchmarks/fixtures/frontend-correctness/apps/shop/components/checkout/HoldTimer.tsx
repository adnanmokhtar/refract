'use client';

import { useEffect, useState } from 'react';
import { useTranslations } from 'next-intl';

// The delivery slot is held for 15 minutes once picked.
export function HoldTimer({ seconds = 900 }: { seconds?: number }) {
  const t = useTranslations('checkout');
  const [left, setLeft] = useState(seconds);

  useEffect(() => {
    const id = setInterval(() => setLeft((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(id);
  }, []);

  return (
    <p role="timer" aria-live="off" className="text-sm tabular-nums">
      {t('held', { minutes: Math.floor(left / 60), seconds: left % 60 })}
    </p>
  );
}
